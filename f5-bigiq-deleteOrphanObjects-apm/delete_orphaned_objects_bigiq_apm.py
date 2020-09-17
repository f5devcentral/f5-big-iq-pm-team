#! /usr/bin/perl -w

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

import requests
from requests.auth import HTTPBasicAuth
import json, getpass, sys, os, re

URL_POST_POLICY_ITEM = "https://localhost/mgmt/cm/access/working-config/apm/policy/policy-item"
INDEX_CONFIG = "https://localhost/mgmt/shared/index/config"
URL_ACCESS_POLICY = "https://localhost/mgmt/cm/access/working-config/apm/policy/access-policy"
URL_COORDINATOR = "https://localhost/mgmt/shared/coordinator/"

REQ_PAYLOAD_COORDINATOR = {"description":"savePolicyTask","timeoutInSeconds":60}

def authenticate(auth):
    response = requests.get(URL_POST_POLICY_ITEM, auth=auth, verify=False)
    return response.status_code

def get_request_query(url, params):
    response = requests.get(url, params=params, auth=auth, verify=False)
    response_json = response.json()
    return response_json

###############
#Authentication
###############
os.system("set-basic-auth on")
print("\nPlease enter the credentials for the BigIQ box (Should have privileges to view, create and modify the access policies):\n")
auth = HTTPBasicAuth(raw_input("Username: "), getpass.getpass())
auth_status = authenticate(auth)

while auth_status != 200:
    if auth_status == 403:
        print("\nUser doesn't have privileges to access policies. User should have privileges to view, create and modify the access policies. Please enter again the credentials for the BigIQ box:\n")
    else:
        print("\nInvalid Credentials. User should have privileges to view, create and modify the access policies. Please enter again the credentials for the BigIQ box:\n")
    
    auth = HTTPBasicAuth(raw_input("Username: "), getpass.getpass())
    auth_status = authenticate(auth)

###############
#Find and delete orphaned objects
###############

existing_access_policy_group = raw_input("Please enter the name of the access group to find orphaned objs: ")
params_find_policy = {"$filter" : "'deviceGroupReference/link' eq 'https://localhost/mgmt/shared/resolver/device-groups/" + existing_access_policy_group + "'"}
params = {'referenceMethod':'kindReferencesResource',
            'referenceKind':'cm:access:working-config:apm:policy:policy-item:policyitemstate',
            'referenceLink': '%s',
            'referenceDepth':4,
            'inflate':True
            }

params_policy = {'referenceMethod':'kindReferencesResource',
            'referenceKind':'cm:access:working-config:apm:policy:access-policy:accesspolicystate',
            'referenceLink': '%s',
            'referenceDepth':4,
            'inflate':True
            }

def put_request(url,req_payload,coordinator_id=None):
    response = requests.put(url, data=json.dumps(req_payload), headers={"content-type":"application/json", "x-f5-rest-coordination-id":coordinator_id}, auth=auth, verify=False)
    response_json = response.json()
    return response_json

def delete(url_list, coordinator_id=None):
    for url in url_list:
        response = requests.delete(url, headers={"x-f5-rest-coordination-id":coordinator_id}, auth=auth, verify=False)

def get_agents_list(policy_item):
    if 'agents' in policy_item:
        for agent in policy_item['agents']:
            agent_list.add(agent['nameReference']['link'])

            resp = get_request(agent['nameReference']['link'])
            if 'customizationGroupReference' in resp:
                customization_group_list.add(resp['customizationGroupReference']['link'])

def find_orphans_items(policy_item):
    if policy_item['itemType'] != 'entry' and policy_item['itemType'] != 'ending':
        params['referenceLink'] = policy_item['selfLink']
        resp = get_request_query(INDEX_CONFIG, params)

        # Policy item is orphan
        if resp['totalItems'] == 0:
            get_agents_list(policy_item)
            print("**** Deleting Orphan Policy Item Caption:%s ****" % policy_item['caption'])
            orphan_policy_item_list.add(policy_item['selfLink'])


# Poicly selfLink -> policy object (itemList)
# if key is present: then change itemList.
# not present then insert and change itemList
def update_policy(orphan_policy_item_list, coordinator_id):
    print("Entering Update Policy")
    dict_policy = {}
    for policy_item_link in orphan_policy_item_list:
        params_policy['referenceLink'] = policy_item_link
        access_policies = get_request_query(INDEX_CONFIG, params_policy)['items']

        if len(access_policies) > 0:
            access_policy = access_policies[0]
            if access_policy['selfLink'] not in dict_policy:
                dict_policy[access_policy['selfLink']] = access_policy
            item_list = dict_policy[access_policy['selfLink']]['itemList']
            item_list_length = len(item_list)
            index = 0
            while index < item_list_length:
                item = item_list[index]
                if item['nameReference']['link'] == policy_item_link:
                    del dict_policy[access_policy['selfLink']]['itemList'][index]
                    break
                index = index + 1

    for policy_link in dict_policy.keys():
        put_request(policy_link, dict_policy[policy_link], coordinator_id)
        print("**** Updating Policy: %s ****" % dict_policy[policy_link]['name'])

def patch_coordinator(coordinator_id):
    response_json = {}
    if coordinator_id != None:

        payload = {
            "id": coordinator_id, 
            "isCommit": True,
            "stage": "UPDATING"
            }
        response = requests.patch(URL_COORDINATOR + coordinator_id, data=json.dumps(payload), headers={"content-type":"application/json"}, auth=auth, verify=False)
        response_json = response.json()
    return response_json

def get_request(url):
    response = requests.get(url, auth=auth, verify=False)
    response_json = response.json()
    return response_json

def post_request(url,req_payload):
    response = requests.post(url, data=json.dumps(req_payload), headers={"content-type":"application/json"}, auth=auth, verify=False)
    response_json = response.json()
    return response_json

print("Started Deletion.....")

no_delete = False
while no_delete is False:
    print("Creating coordination task.....")

    coordinator = post_request(URL_COORDINATOR, REQ_PAYLOAD_COORDINATOR)
    coordinator_id = coordinator["id"]

    no_delete = True

    agent_list = set()
    orphan_policy_item_list = set()
    customization_group_list = set()

    all_policy_items = get_request_query(URL_POST_POLICY_ITEM, params_find_policy)
    for item in all_policy_items['items']:
        find_orphans_items(item)
      
    update_policy(orphan_policy_item_list, coordinator_id)

    if len(orphan_policy_item_list) > 0:
        no_delete = False
        delete(orphan_policy_item_list, coordinator_id)

    if len(agent_list) > 0:
        no_delete = False
        delete(agent_list, coordinator_id)

    if len(customization_group_list) > 0:
        no_delete = False
        delete(customization_group_list, coordinator_id)

    update_coordinator = patch_coordinator(coordinator_id)
    if no_delete is False:
        while update_coordinator["stage"] != "COMPLETED":
            update_coordinator = get_request(URL_COORDINATOR + coordinator_id)
