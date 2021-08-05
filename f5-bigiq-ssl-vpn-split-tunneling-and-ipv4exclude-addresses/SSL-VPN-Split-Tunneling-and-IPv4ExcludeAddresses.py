#! /usr/bin/perl -w

#################################################################################
# Copyright 2021 by F5, Inc.
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
from pprint import pprint

NETWORK_ACCESS_URI = "https://localhost/mgmt/cm/access/working-config/apm/resource/network-access"
ACCESS_GROUP_URI = "https://localhost/mgmt/shared/resolver/device-groups/"

def get_username():
    return raw_input("Username: ")

def get_password():
    return getpass.getpass()

def get_access_group_name():
    return raw_input("Access Group name: ")

def get_ipv4_exlude_address_list():
    return raw_input("IPV4 Exclude Address Space list: ")

def should_update_all():
    return raw_input("Do you want to update all of them? (y/n) : ") == "y"

###############
#Authentication
###############
print("This script will help you ADD new IP addresses to the IPV4 Exclude Address Space list for device-specific Network Access configurations for a specific Access Group. This script will update the address list irrespective of whether split tunneling is enabled or not.")
print("This script changes the configurations on BIG-IQ. You need to evaluate and deploy them after running the script.")
print("\nNOTE: This script will set-basic-auth on. Please turn it off using the command, set-basic-auth off, after running the script if you don't want to keep it ON.")
os.system("set-basic-auth on")
print("\nPlease enter the credentials for User on the BIG-IQ box (User must have privileges to view and modify the Network Access configurations):\n")
auth = HTTPBasicAuth(get_username(), get_password())
networkAccessGETResponse = requests.get(NETWORK_ACCESS_URI + "?$select=name", auth=auth, verify=False)

while networkAccessGETResponse.status_code != 200:
    if networkAccessGETResponse.status_code == 403:
        print("\nUser doesn't have privileges to view Network Access configurations. User must have privileges to view, create and modify. Please try again:\n")
    else:
        print("\nInvalid credentials. Please try again:\n")

    auth = HTTPBasicAuth(get_username(), get_password())
    networkAccessGETResponse = requests.get(NETWORK_ACCESS_URI + "?$select=name", auth=auth, verify=False)

###############
# User Inputs:
# Access Group
# IPV4 Exclude Address Space 
###############
print("\nEnter the Access Group name of the BIG-IP devices for which you want to update the Network Access configurations.")
access_group_name = get_access_group_name()

access_group_status = requests.get(ACCESS_GROUP_URI + access_group_name, auth=auth, verify=False).status_code
if access_group_status == 404:
    print("\n Access Group (" + access_group_name + ") does not exist. Please check and try again.")
    sys.exit()

################
#Utilities
################

def get_request_query(url, params):
    response = requests.get(url, params=params, auth=auth, verify=False)
    response_json = response.json()
    return response_json

def convertAddressFormat(addr):
    """
    If addr is of the form 192.168.1.64/255.255.255.0, convert it
    to 192.168.1.64/24, otherwise return the address as-is.
    """
    addr, mask = addr.split("/")
    if "." in mask:
        mask = sum([ bin(int(bits)).count("1") for bits in mask.split(".") ])
    return addr + "/" + str(mask)

def getUserInputForAddressList(): 
    print("\nEnter the IPV4 Exclude Address Space list as a comma seperated list with no white spaces. "
          " You can enter it in the following formats (examples below) \n1. Using Mask: 192.168.0.1/255.255.252.0"
          "\n2. Using Subnet: 192.168.0.1/22 \n")
    ipv4ExcludeAddressListString = get_ipv4_exlude_address_list()
    ipv4ExcludeAddressOriginalList = ipv4ExcludeAddressListString.split(",")
    ipv4ExcludeAddressList = []
    for ipv4ExcludeAddress in ipv4ExcludeAddressOriginalList:
        ipv4ExcludeAddress = convertAddressFormat(ipv4ExcludeAddress)
        ipv4ExcludeAddressList.append(ipv4ExcludeAddress)
    return ipv4ExcludeAddressList

def checkPatchResponse(patchResponse):
    if (patchResponse.status_code == 200):
        response = patchResponse.json()
        print("Successfully updated: " + response["name"])
    else:
        print("Failed to PATCH the configurations. Please verify your inputs and try again. HTTP Error Code: " + patchResponse.status_code)
        sys.exit()

paramsForGroupFilter  = { "$filter": " 'lsoDeviceReference/link' eq '*' and 'isLsoShared' eq 'false' and 'deviceGroupReference/link' eq 'https://localhost/mgmt/shared/resolver/device-groups/"+ access_group_name +"'", "$select": "selfLink,addressSpaceExcludeSubnet"}
allNetworkAccessObjects = get_request_query(NETWORK_ACCESS_URI, paramsForGroupFilter)

if allNetworkAccessObjects["totalItems"] == 0:
    print("\nThere aren't any device-specific Network Access configurations under the given Access Group.")
    sys.exit()
else:
    print("\nFound "+ str(allNetworkAccessObjects["totalItems"]) +" configurations under the Access Group "+ access_group_name +".\n")

if should_update_all():
    ipv4ExcludeAddressList = getUserInputForAddressList() 
    for networkAccessObject in allNetworkAccessObjects["items"]:
        for newIpAddress in ipv4ExcludeAddressList:
            if "addressSpaceExcludeSubnet" not in networkAccessObject:
                networkAccessObject["addressSpaceExcludeSubnet"] = []
            networkAccessObject["addressSpaceExcludeSubnet"].append({"subnet": newIpAddress, "generation": 0, "lastUpdateMicros": 0})
        url = networkAccessObject["selfLink"]
        patchResponse = requests.patch(url, data=json.dumps(networkAccessObject), headers={"content-type":"application/json"}, auth=auth, verify=False)
        checkPatchResponse(patchResponse)
else:
    sys.exit()