#!/usr/bin/env python

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

import requests
from requests.auth import HTTPBasicAuth
import json, getpass, sys, os, re

## CHANGE QUEUE
# 03/14/2019: v1.0  K.Rana@f5.com     Initial version

## DESCRIPTION
# Script for adding and modifying branch rule with advanced expression to access policy

print "\n\n\nThis script will allow you to set advacnced expression for branch rules in access policies (per-session and per-request)"  

print "\n\n======================================================  ATTENTION  =================================================================="
print "PLEASE MAKE SURE THE POLICY YOU WANT TO MODIFY IS NOT IN DRAFT MODE. MAKE SURE YOU HAVE SAVED YOUR POLICY BEFORE RUNNING THIS SCRIPT."  
print "=====================================================================================================================================\n"
ACCESS_API = "https://localhost/mgmt/cm/access/working-config/apm/policy/access-policy/"
print "\nAuthentication Information: "
auth = HTTPBasicAuth(raw_input("Username: "), getpass.getpass())


def post_profile_policy_request(url,req_payload,coordinator_id):
    response = requests.post(url, data=json.dumps(req_payload), headers={"content-type":"application/json", "x-f5-rest-coordination-id":coordinator_id}, auth=auth, verify=False)
    return response, response.json()

def get_request(url):
    response = requests.get(url, auth=auth, verify=False)
    response_json = response.json()
    return response_json

def get_request_query(url,params):
    response = requests.get(url, params=params, auth=auth, verify=False)
    response_json = response.json()
    return response_json

def get_request_query_comp(url, params):
    response = requests.get(url, params=params, auth=auth, verify=False)
    response_json = response.json()
    return response, response_json

def put_request(url,req_payload,coordinator_id=None):

    if coordinator_id == None:
        response = requests.put(url, data=json.dumps(req_payload), headers={"content-type":"application/json"}, auth=auth, verify=False)
    else:
        response = requests.put(url, data=json.dumps(req_payload), headers={"content-type":"application/json", "x-f5-rest-coordination-id":coordinator_id}, auth=auth, verify=False)

    response_json = response.json()
    return response_json

def put_request_comp(url,req_payload,coordinator_id=None):

    if coordinator_id == None:
        response = requests.put(url, data=json.dumps(req_payload), headers={"content-type":"application/json"}, auth=auth, verify=False)
    else:
        response = requests.put(url, data=json.dumps(req_payload), headers={"content-type":"application/json", "x-f5-rest-coordination-id":coordinator_id}, auth=auth, verify=False)

    response_json = response.json()
    return response, response_json

def process_item(item, postfix):
    link = item["nameReference"]["link"]

    # print "Link is: " + link

    # get policy item
    policyItem = get_request(link)

    action = raw_input("\nWhich operation you want to perform? \nModify branch (m) \nCreate new branch (c) \nExit (e) \n\nPlease enter (m/c/e): ")

    if action != "m" and action != "c":
        return True

    if action == "m":

        print "========== Modify Existing Rule ==========\n"
        print "Current Branches on ", item["name"], " : \n"

        for i, rule in enumerate(policyItem["rules"]):
            print i+1, rule["caption"]
        print "\n"

        ruleIndex = input("Which branch do you want to modify? ")
        while not 0 < ruleIndex <= len(policyItem["rules"]):
            ruleIndex = input("Out of Range, Please Enter Again: ")

        ruleItem = policyItem["rules"][ruleIndex-1]

        # in case no expression in this rule, add property first
        if "expression" not in ruleItem:
            ruleItem["expression"] = ""

        print "Current Branch Name: ", ruleItem["caption"]
        print "Current Advanced Expression: ", ruleItem["expression"]

        newExpr = raw_input("Enter new advanced expression: ")
        ruleItem["expression"] = newExpr

        res = put_request_comp(link, policyItem)

        print "\nModifying Branch: ", ruleItem["caption"], "\tNew advanced expression: ", ruleItem["expression"]
        if res[0].status_code == 200:
            print "Result: SUCCESS"
        else:
            print "Result: FAILED"
            print res[1]




    else:

        print "========== Create New Branch ==========\n"
        caption = raw_input("Please enter the new branch name: ")
        expression = raw_input("Please enter the advanced expression: ")

        newRule = {"caption": caption, "expression": expression}

        denyPolicyName = policyName + postfix
        DENY_POLICY_FILTER = {"$filter" : "'deviceGroupReference/link' eq 'https://localhost/mgmt/shared/resolver/device-groups/" + accessGroup + "' and 'name' eq '" + denyPolicyName + "'"}
        POLICY_API = "https://localhost/mgmt/cm/access/working-config/apm/policy/policy-item/"

        denyPolicyItems = get_request_query(POLICY_API, DENY_POLICY_FILTER)
        selfLink = denyPolicyItems["items"][0]["selfLink"]

        newRule["nextItemReference"] = {"link": selfLink}

        policyItem["rules"].append(newRule)

        res = put_request_comp(link, policyItem)

        print "\nCreating Branch: ", newRule["caption"], "\tAdvanced Expression: ", newRule["expression"]
        if res[0].status_code == 200:
            print "Result: SUCCESS"
        else:
            print "Result: FAILED"
            print res[1]


while True:
    accessGroup = raw_input("\nPlease enter the Access Group name: ")
    policyName = raw_input("Please enter the policy name: ")
    params_find_policy = {"$filter" : "'deviceGroupReference/link' eq 'https://localhost/mgmt/shared/resolver/device-groups/" + accessGroup + "' and 'name' eq '" + policyName + "'", "$expand": "itemList/nameReference"}

    print "\nPolicy Name: " + policyName
    try:
        res = get_request_query(ACCESS_API, params_find_policy)
        # print res
        if len(res["items"]) == 0:
            print "No policy found, please try again \n"

        else: 
            #rawItems = res["items"][0]["itemList"]
            rawItems = list((subItem, item["type"]) for item in res["items"] for subItem in item["itemList"])
            items = list(filter(lambda i: i[0]["name"][len(policyName):].startswith("_act_"), rawItems))
            if len(items) == 0:
                print "No valid policy found \n"
            else:
                break
    except ValueError:
        print "\nInvalid Access Group or policy name, please try again\n"
    
    

# policyName = "KETAN_Access_Profile"

# print res["generation"]

# link = res["items"][0]["itemList"][0]["nameReference"]["link"]

try:
    while True:
        print "\nThe Policy Item List: \n"

        try:
            for i, item in enumerate(items):
                # print i+1, item[0]["name"]
                nameRes = get_request(item[0]["nameReference"]["link"])
                print i+1, nameRes["caption"] 
        except ValueError:
            print "\nSome Errors Occur When Retrieving Policy Item, Please Try again\n"

        itemIndex = input("\nWhich policy item do you want to modify? Please enter the number: ")
        while not 0 < itemIndex <= len(items):
            itemIndex = input("\nOut of Range, Please try again: ")

        while True:
            if items[itemIndex-1][1] == "access-policy":
                postfix = "_end_deny"
            else:
                postfix = "_end_reject"
            r = process_item(items[itemIndex-1][0], postfix)
            if r:
                break
            else:
                r = raw_input("Continue editing this policy item? (y/n): ")
                if r == "n":
                    break

        contd_s = raw_input("\nContinue editing this policy? (y/n): ")
        if contd_s != "y":
            break

except KeyboardInterrupt:
    print "Terminated \n"
