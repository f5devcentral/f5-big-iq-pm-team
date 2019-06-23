#!/usr/bin/env bash
# Uncomment set command below for code debugging bash
#set -x

#################################################################################
# Copyright 2018 by F5 Networks, Inc.
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

# 07/18/2018: v1.0  r.jouhannet@f5.com     Initial version
# 07/25/2018: v1.1  r.jouhannet@f5.com     Add <full path> in the Usage. also correct redacted-hostname.
# 07/27/2018: v1.2  r.jouhannet@f5.com     Hash IP address and hostname
# 07/31/2018: v1.3  r.jouhannet@f5.com     Fix issue with } at the end of the json file.
# 08/24/2018: v1.4  r.jouhannet@f5.com     Add encryption to the obfuscated hashed variables (mac, IP and hostname)

### Secret password to encrupt the md5 hash
secret_password="changme"

# Uncomment set command below for code debugging bash
#set -x

echo -e "\nThe script replaces the IP address, MAC address and the host name with with encrypted hash value (md5) in a JSON report."
if [[ -z $1 ]]; then

    echo -e "\n-> No JSON report specified.\n\nUsage: ./f5_sanitize_usage_report.sh <full path>/report.json\n"
    exit 1;

elif [ -f $1 ]; then
    # Backup original report
    mv $1 $1.orig
    # Setting  internal field separator to null to keep the space
    IFS='';
    # Reading file line by line
    while read -r line; 
    do 
        if [[ $line = *"macAddress"* ]]; then
            # if macAddress, hash it and replace it with the hash
            macAddressMD5=$(echo $line | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | md5sum | cut -f1 -d' ' | openssl base64 -a -salt -k $secret_password)
            #echo "DEBUG $macAddressMD5"
            echo $line | sed -r "s#[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}#$macAddressMD5#g" >> $1
        elif [[ $line = *"address"* ]]; then
            # if address (IP), hash it and replace it with the hash
            ipAddressMD5=$(echo $line | grep -o -E '[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]' | md5sum | cut -f1 -d' ' | openssl base64 -a -salt -k $secret_password)
            #echo "DEBUG $ipAddressMD5"
            echo $line | sed -r "s#[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]#$ipAddressMD5#g" >> $1
        elif [[ $line = *"hostname"* ]]; then
            # hostname, hash it and replace it with the hashx22=" x27='
            hostname=$(echo $line | awk -F'"' '$2=="hostname"{print $4}')
            hostnameMD5=$(echo $line | awk -F'"' '$2=="hostname"{print $4}' | md5sum | cut -f1 -d' ' | openssl base64 -a -salt -k $secret_password)
            #echo "DEBUG $hostnameMD5"
            echo $line | sed -r "s#$hostname#$hostnameMD5#g" >> $1
        else
            # if no macAddress or address (IP), do nothing
            echo $line >> $1
        fi
    done < $1.orig

    # Fix missing } at the end
    echo -e "}" >> $1

    echo -e "\n-> Backup prior modification: $1.orig"
    echo -e "-> $1 was updated obfuscating with encryption IP addresses, MAC addresses and hostnames.\n"
    exit 0;
else
    
    echo -e "\n-> JSON report specified “$1” does not exist. Please check filename specified in the argument.\n"
    ls -l | grep -v total | grep -v $0
    exit 2;
fi