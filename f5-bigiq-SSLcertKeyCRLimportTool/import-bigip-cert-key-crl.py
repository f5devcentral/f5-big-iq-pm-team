#!/usr/bin/env python

#################################################################################
# Copyright 2020 by F5 Networks, Inc.
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.
#################################################################################

# 04/05/2018: v1.0  K.Goodsell@F5.com     Initial version
# 08/14/2018: v1.1  r.jouhannet@f5.com    Add Apache License, rename the script import-bigip-cert-key-crl.py, update help.

# Note: This script targets the python environment on BIG-IQ 5.4 and above.
# The python version there is 2.6.6, and a few additional useful libraries are available
# (such as argparse). Eventually making this work in generic Linux environments
# shouldn't be too difficult.

import argparse
import json
import logging
import os
import pickle
import requests
import signal
import subprocess
import sys
import time
import urlparse

# BIG-IQ is limited to importing from this path for security reasons.
FILE_IMPORT_DIR = '/var/config/rest/downloads'

IMPORT_TASK_PATH = 'cm/adc-core/tasks/certificate-management'

FINAL_TASK_STATUSES = [
    'CANCELED',
    'FAILED',
    'FINISHED',
]

def get_rest_path(uri):
    '''
    Given a URI string, extract the path portion and remove any leading /mgmt.
    The resulting string will have no leading slash.
    '''
    parsed = urlparse.urlparse(uri)
    path_bits = parsed.path.split('/')
    # Result looks like ['', 'mgmt', 'cm', 'more']
    if path_bits[:2] == ['', 'mgmt']:
        path_bits = [''] + path_bits[2:]

    return '/'.join(path_bits[1:])

def make_selflink(path):
    return 'https://localhost/mgmt/' + path

def make_local_uri(path):
    return 'http://localhost:8100/' + path

class FileObjectTypes(object):
    '''
    Simple type to record information about the types we operate on.
    '''

    class FileObjectType(object):
        def __init__(self, display_name, mcp_type_name, rest_path, bigiq_kind,
                     task_associate_cmd, task_reference_name):
            self._display_name = display_name
            self._mcp_type_name = mcp_type_name
            self._rest_path = rest_path
            self._bigiq_kind = bigiq_kind
            self._task_associate_cmd = task_associate_cmd
            self._task_reference_name = task_reference_name

        @property
        def display_name(self):
            return self._display_name

        @property
        def mcp_type_name(self):
            return self._mcp_type_name

        @property
        def rest_path(self):
            return self._rest_path

        @property
        def bigiq_kind(self):
            return self._bigiq_kind

        @property
        def task_associate_cmd(self):
            return self._task_associate_cmd

        @property
        def task_reference_name(self):
            return self._task_reference_name

        def get_local_uri(self):
            return make_local_uri(self._rest_path)

    CERT = FileObjectType(
        'Certificate',
        'certificate_file_object',
        'cm/adc-core/working-config/sys/file/ssl-cert',
        'cm:adc-core:working-config:sys:file:ssl-cert:adcsslcertstate',
        'ASSOCIATE_CERT',
        'certReference')

    KEY = FileObjectType(
        'Key',
        'certificate_key_file_object',
        'cm/adc-core/working-config/sys/file/ssl-key',
        'cm:adc-core:working-config:sys:file:ssl-key:adcsslkeystate',
        'ASSOCIATE_KEY',
        'keyReference')

    CRL = FileObjectType(
        'CRL',
        'certificate_revocation_list_file_object',
        'cm/adc-core/working-config/sys/file/ssl-crl',
        'cm:adc-core:working-config:sys:file:ssl-crl:adcsslcrlstate',
        'ASSOCIATE_CRL',
        'crlReference')

    all_types = [CERT, KEY, CRL]

BUILTIN_OBJECTS = [
    (FileObjectTypes.CERT.bigiq_kind, '/Common/default.crt'),
    (FileObjectTypes.CERT.bigiq_kind, '/Common/ca-bundle.crt'),
    (FileObjectTypes.CERT.bigiq_kind, '/Common/f5-irule.crt'),
    (FileObjectTypes.KEY.bigiq_kind, '/Common/default.key'),
    (FileObjectTypes.KEY.bigiq_kind, '/Common/f5_api_com.key'),
]

class FileObject(object):
    '''
    Object representing information about a specific file object.
    '''

    def __init__(self, fullpath, rest_path, cache_path, password, obj_type):
        self._fullpath = fullpath
        self._rest_path = rest_path
        self._cache_path = cache_path
        self._password = password
        self._obj_type = obj_type

    def __repr__(self):
        return ('<FileObject %r, %r, %r>' %
                (self._fullpath, self._rest_path, self._cache_path))

    @property
    def fullpath(self):
        return self._fullpath

    @property
    def rest_path(self):
        return self._rest_path

    @property
    def cache_path(self):
        return self._cache_path

    @property
    def password(self):
        return self._password

    @property
    def obj_type(self):
        return self._obj_type

    @classmethod
    def from_object_states(cls, bigip_state, bigiq_state):
        bigip_fullpath = bigip_state['name']
        bigiq_fullpath = get_fullpath(bigiq_state)

        if bigip_fullpath != bigiq_fullpath:
            raise StandardError(
                ("BIG-IP fullPath (%s) doesn't match BIG-IQ fullPath (%s)" %
                 (bigip_fullpath, bigiq_fullpath)))

        bigip_checksum = bigip_state['checksum']
        bigiq_checksum = bigiq_state['checksum']

        if bigip_checksum != bigiq_checksum:
            raise StandardError(
                ("Checksum mismatch, BIG-IP:%s BIG-IQ:%s" %
                 (bigip_checksum, bigiq_checksum)))

        for obj_type in FileObjectTypes.all_types:
            if bigiq_state['kind'] == obj_type.bigiq_kind:
                found_type = obj_type
                break
        else:
            raise StandardError("Didn't find matching kind for %s" %
                                bigiq_state['kind'])

        return FileObject(
            bigip_fullpath,
            get_rest_path(bigiq_state['selfLink']),
            bigip_state['cache_path'],
            bigip_state.get('passphrase'),
            found_type)

def make_bigip_query_cmd(object_type):
    # This will be joined into one line, but it's easier to read this way.
    script = [
        'import f5.mcp, pickle;',
        # Include only the few attributes we care about, since not everything
        # can be pickled/unpickled.
        'attrs=["cache_path","name","checksum","passphrase"];',
        # Function to translate objects into a pickleable form.
        'm=lambda d: dict((k,v) for (k,v) in d.items() if k in attrs);',
        'r=f5.mcp.MCPConnection().query_all("' + object_type + '");',
        'print pickle.dumps([m(o) for o in r])'
    ]

    return [
        'python',
        '-c',
        ''.join(script)
    ]

def make_associate_task_state(rest_path, file_path, password, obj_type):
    body = {
        'command': obj_type.task_associate_cmd,
        'filePath': file_path,
        obj_type.task_reference_name: {
            "link": make_selflink(rest_path)
        },
    }

    if password is not None:
        body['keyPassphrase'] = password

    return body

def check_http_response(resp):
    try:
        resp.raise_for_status()
    except requests.exceptions.HTTPError:
        logging.info("Failed HTTP request, response body: %s", resp.text)
        raise

    return resp

def run_task(session, uri, body):
    # This particular request requires authentication, but it doesn't check the
    # authentication and basic auth apparently works even if not enabled.
    resp = check_http_response(
        session.post(uri, data=json.dumps(body), auth=('admin','')))

    task = resp.json()

    task_uri = make_local_uri(get_rest_path(task['selfLink']))

    while task['status'] not in FINAL_TASK_STATUSES:
        time.sleep(.5)
        resp = check_http_response(session.get(task_uri))
        task = resp.json()

    return task

def escape_for_openssh(cmd):
    # OpenSSH joins the words of the command together with a space between, then
    # sends that as a single command string to the server, which then passes it
    # to a shell. That really messes up cases like spaces or quotation marks in
    # words.
    #
    # Putting single-quotes around every word solves most of these problems, but
    # not the case of a word with a single-quote inside. To address that, we
    # replace ' with '"'"'. The first ' ends the single-quoted string, " starts
    # a new double-quoted string, second ' is the content of the double-quoted
    # string, second " ends the double-quoted string, and the final ' restarts
    # the single-quoted string for the remainder of the word. Yeah, it's weird,
    # but it seems to do the job.

    escaped_words = []
    for word in cmd:
        escaped_words.append("'" + word.replace("'", "'\"'\"'") + "'")

    return ' '.join(escaped_words)

class SshConnection(object):

    CONTROL_PATH_ARGS = ['-o', 'ControlPath=/tmp/ssl-file-import-%l%h%p%r']
    NO_PASSWORD_ARGS = [
        '-o', 'KbdInteractiveAuthentication=no',
        # Have to also disable ChallengeResponseAuthentication, otherwise
        # KbdInteractiveAuthentication is not really disabled.
        '-o', 'ChallengeResponseAuthentication=no',
    ]

    def __init__(self, addr, port=None):
        self._addr = addr
        self._port = port
        self._master_proc = None

        self._start_master_proc()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()

    def run_cmd(self, cmd):
        '''
        Run the given command (specified as a list, e.g. ['ls', '-l']). Waits
        for the command to complete and returns a triple (exit_code, stdout_str,
        stderr_str).
        '''

        ssh_cmd = [
            'ssh',
        ]

        ssh_cmd += self.NO_PASSWORD_ARGS
        ssh_cmd += self.CONTROL_PATH_ARGS
        ssh_cmd += self._port_args('-p')

        ssh_cmd += [
            self._user_host(),
            escape_for_openssh(cmd)
        ]

        proc = subprocess.Popen(
            ssh_cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)

        (stdoutdata, stderrdata) = proc.communicate()

        return (proc.returncode, stdoutdata, stderrdata)

    def get_file(self, remote_src_path, local_dest_path):
        '''
        Copies the given remote file to the given local file.
        '''

        scp_cmd = [
            'scp',
            '-q',
        ]

        scp_cmd += self.NO_PASSWORD_ARGS
        scp_cmd += self.CONTROL_PATH_ARGS
        scp_cmd += self._port_args('-P')

        scp_cmd += [
            self._user_host() + ":" + remote_src_path,
            local_dest_path,
        ]

        subprocess.check_call(scp_cmd)

    def close(self):
        proc = self._master_proc
        self._master_proc = None

        if proc is not None:
            proc.send_signal(signal.SIGINT)
            proc.wait()

    def _user_host(self):
        return 'root@' + self._addr

    def _port_args(self, opt_str):
        if self._port is None:
            return []
        else:
            return [opt_str, str(self._port)]

    def _start_master_proc(self):

        ssh_cmd = [
            'ssh',
            '-q',
            '-N',
            '-o', 'ControlMaster=yes',
        ]

        ssh_cmd += self.CONTROL_PATH_ARGS
        ssh_cmd += self._port_args('-p')

        ssh_cmd += [
            self._user_host()
        ]

        self._master_proc = subprocess.Popen(ssh_cmd)

        # Wait for the control socket to exist.
        check_cmd = [
            'ssh',
            '-q',
            '-O', 'check',
        ]

        check_cmd += self.CONTROL_PATH_ARGS
        check_cmd += self._port_args('-p')

        check_cmd += [
            self._user_host()
        ]

        master_rc = self._master_proc.poll()

        while master_rc is None and subprocess.call(check_cmd) != 0:
            time.sleep(.5)
            master_rc = self._master_proc.poll()

        if master_rc is not None:
            raise StandardError(
                "ssh connection failed, exit code: %d" % master_rc)

def get_bigip_file_objects(connection, object_type_name):
    rc, stdout, stderr = connection.run_cmd(
        make_bigip_query_cmd(object_type_name))

    if (rc != 0):
        logging.error(
            "Non-zero exit from BIG-IP object retrieval script. RC=%d", rc)
        logging.error("Command stdout:\n%s", stdout)
        logging.error("Command stderr:\n%s", stderr)
        raise StandardError("Failed to get object info from BIG-IP")

    return pickle.loads(stdout)

def get_bigiq_file_objects(session, uri):
    r = check_http_response(session.get(uri))

    return r.json()['items']

def is_managed(o):
    return o.get('fileReference', {}).get('link') is not None

def is_builtin(o):
    kind_path = (o['kind'], get_fullpath(o))

    return kind_path in BUILTIN_OBJECTS

def get_fullpath(o):
    '''
    For BIG-IQ objects, the full path is stored in three separate fields:
    partition, subPath, and name.
    '''
    part = '/' + o['partition'].strip('/')
    subpath = '/' + o.get('subPath', '').strip('/')
    name = '/' + o['name']

    if subpath == '/':
        subpath = ''

    return part + subpath + name

def hide_passwords(objs):
    result = []
    for obj in objs:
        d = dict(obj)
        if 'passphrase' in d:
            d['passphrase'] = '<REDACTED>'
        result.append(d)

    return result

def find_unmanaged_objects(session, bigip_connection, object_type):
    type_name = object_type.display_name

    # Fetch the objects from each device.
    ip_objects = get_bigip_file_objects(bigip_connection,
                                        object_type.mcp_type_name)
    logging.debug(
        "Found BIG-IP %s objects:\n%s",
        type_name,
        hide_passwords(ip_objects))
    iq_objects = get_bigiq_file_objects(session, object_type.get_local_uri())
    logging.debug("Found BIG-IQ %s objects:\n%s", type_name, iq_objects)


    # Convert to dicts indexed by fullpath.
    ip_by_path = dict((obj['name'], obj) for obj in ip_objects)
    iq_by_path = dict((get_fullpath(obj), obj) for obj in iq_objects)

    result = []
    for path, iq_object in iq_by_path.iteritems():

        if is_managed(iq_object):
            # already managed, ignore.
            logging.debug("Ignoring managed %s %s", type_name, path)
            continue

        if is_builtin(iq_object):
            # builtin, ignore
            logging.debug("Ignoring builtin %s %s", type_name, path)
            continue

        ip_object = ip_by_path.get(path)
        if ip_object is None:
            # This BIG-IP doesn't have the file, nothing to do with it.
            logging.debug(
                "No corresponding BIG-IP object for %s %s, ignoring",
                type_name,
                path)
            continue

        if 'checksum' not in iq_object:
            logging.warning(
                "Missing BIG-IQ checksum for %s %s, object type may be unsupported",
                type_name,
                get_fullpath(iq_object))
        elif ip_object['checksum'] != iq_object.get('checksum', ''):
            logging.warning(
                "Checksums don't match for %s %s",
                type_name,
                ip_object['name'])
            continue
        else:
            result.append(FileObject.from_object_states(ip_object, iq_object))

    return result

def find_all_unmanaged_objects(session, bigip_connection):
    unmanaged_files = []
    for typ in FileObjectTypes.all_types:
        unmanaged_files += find_unmanaged_objects(session, bigip_connection, typ)

    return unmanaged_files

def fetch_files(bigip_connection, file_objects):
    for f in file_objects:
        logging.info("Downloading file %s", f.cache_path)
        bigip_connection.get_file(f.cache_path, FILE_IMPORT_DIR)

def associate_files(session, file_objects):
    success_count = 0
    for f in file_objects:
        file_path = os.path.join(
            FILE_IMPORT_DIR,
            os.path.basename(f.cache_path))

        logging.info("Associating %s %s", f.obj_type.display_name, file_path)

        task_body = make_associate_task_state(
            f.rest_path,
            file_path,
            f.password,
            f.obj_type)

        final_task = run_task(
            session,
            make_local_uri(IMPORT_TASK_PATH),
            task_body)

        final_status = final_task['status']
        if final_status == 'FINISHED':
            logging.info(
                "Associate succeeded for %s %s",
                f.obj_type.display_name,
                file_path)
            success_count += 1
        else:
            logging.warning(
                "Associate for %s %s was not successful, final task state: %s",
                f.obj_type.display_name,
                file_path,
                final_task)

    logging.info(
        "Successfully associated %d of %d files",
        success_count,
        len(file_objects))

def parse_arguments(args):
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description='Automate import of SSL Cert, Key & CRL from BIG-IP to BIG-IQ.',
        epilog='\n'.join([
            "Discover and import LTM services before using this script.",
            "",
            "All supported file SSL Cert, Key & CRL that exist as unmanaged objects on this",
            "BIG-IQ which can be found on the target BIG-IP will be imported.",
            "",
            "The target BIG-IP will be accessed over ssh using the BIG-IP root",
            "account. Enter the root user's password if prompted.",
            "",
            "Repeat with additional target BIG-IPs to import more file objects.",
        ]))

    parser.add_argument('bigip', help='address of BIG-IP to import SSL Cert, Key & CRL from')
    parser.add_argument('--log-file', '-l', help='log to the given file name')
    parser.add_argument(
        '--log-level',
        choices=['debug', 'info', 'warning', 'error', 'critical'],
        default='info',
        help='set logging to the given level (default: %(default)s)')
    parser.add_argument('-p', '--port', type=int, help='BIG-IP ssh port (default: 22)')

    # Other ideas here include whitelist/blacklist for files to import, options
    # to select which file types to import. But that would just leave some files
    # unmanaged on BIG-IQ, so it's not clear that it would be useful. The user
    # can opt out of certain files by removing the object from BIG-IQ.

    return parser.parse_args(args)

################################################################################
#
# Main execution
#
################################################################################

def main(args=None):
    if args is None:
        args = sys.argv[1:]

    arguments = parse_arguments(args)

    # Set up logging
    loglevel = None
    if arguments.log_level:
        loglevel = getattr(logging, arguments.log_level.upper())

    logging.basicConfig(
        filename=arguments.log_file,
        level=loglevel,
        format='%(asctime)s:%(levelname)s:%(message)s')

    session = requests.Session()

    with SshConnection(arguments.bigip, arguments.port) as conn:
        unmanaged_files = find_all_unmanaged_objects(session, conn)

        if unmanaged_files:
            fetch_files(conn, unmanaged_files)
            associate_files(session, unmanaged_files)
        else:
            logging.info("No files found to import")

    return 0

if __name__ == '__main__':
    sys.exit(main())
