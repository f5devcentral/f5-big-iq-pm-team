#!/bin/bash
# Uncomment set command below for code debugging bash
#set -x

#################################################################################
# Copyright 2019 by F5 Networks, Inc.
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

## CHANGE QUEUE
# 01/18/2019: v1.0  r.jouhannet@f5.com     Initial version
# 01/24/2019: v1.1  r.jouhannet@f5.com     Fix spaces causing issue in JSON objects, move the loop on port/addresses objects under rule-lists
#                                          Add debug option, add check if the script is already running, add overall runtime.

## DESCRIPTION
# Written for BIG-IQ 5.4 and up.
# Script to export shared AFM objects from 1 BIG-IQ to another.
# The script execution time will depend on the number of objects so if you schedule it in crontab, make sure you take in account the running time for your config.
# e.g. 17.6k objects takes approx ~13 hours

# The script will:
#   1. Create a AFM snapshot on BIG-IQ source
#   2. Export from the snapshot port lists, address lists, rule lists, policies and policy rules
#      Note: the script only syncs objects that are in use in the policy
#   3. Import in BIG-IQ target objects exported previously

# The Target BIG-IQ, login and password need to be specified in the parameters of the script.
# Basic Authentication needs to be turned on on the target BIG-IQ (set-basic-auth on)

# Usage: ./sync-shared-afm-objects.sh 10.1.1.6 admin password

# The script should be installed under /shared/scripts on the BIG-IQ where you want to export the objects.
# mkdir /shared/scripts
# chmod +x /shared/scripts/sync-shared-afm-objects.sh 
#
# Make sure you test the script before setting it up in cronab. It is also recommended to test the script in crontab.
# Configure the script in crontab, example once a day at 4pm
# 00 16 * * * /shared/scripts/sync-shared-afm-objects.sh 10.1.1.6 admin password > /dev/null
# 
#┌───────────── minute (0 - 59)
#│ ┌───────────── hour (0 - 23)
#│ │ ┌───────────── day of month (1 - 31)
#│ │ │ ┌───────────── month (1 - 12)
#│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday;
#│ │ │ │ │                                       7 is also Sunday on some systems)
#│ │ │ │ │";
#│ │ │ │ │";
#* * * * *
#
#
# To run in debug mode, add debug at the end of the command:
# e.g.: ./sync-shared-afm-objects.sh 10.1.1.6 admin password debug
#

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

already=$(ps -ef | grep "$0" | grep bash | grep -v grep | wc -l)
if [ $already -gt 2 ]; then
    echo "The script is already running. Waiting 1 hour."
    sleep 3600
    already=$(ps -ef | grep "$0" | grep bash | grep -v grep | wc -l)
elif [ $already -gt 2 ]; then
    echo "The script is already running. Exiting."
    exit 1
fi

if [[ -z $1 || -z $2 || -z $3 ]]; then
    echo -e "\nThe script will:\n\t1. Create a AFM snapshot on BIG-IQ source\n \t2. Export from the snapshot port lists, address lists, rule lists, policies and policy rules\n \t3. Import in BIG-IQ target objects exported previously"
    echo -e "\n${RED}=> No Target BIG-IQ, login and password specified ('set-basic-auth on' on target BIG-IQ)${NC}\n\n"
    echo -e "Usage: ${BLUE}./sync-shared-afm-objects.sh 10.1.1.6 admin password [debug]${NC}\n"
    exit 1;
else
    SECONDS=0
    bigiqIpTarget=$1
    bigiqAdminTarget=$2
    bigiqPasswordTarget=$3
    debug=$4

    send_to_bigiq_target () {
        # parameter 1 is the URL, parameter 2 is the JSON payload, parameter 3 is the method (PUT or POST)
        json="$2"
        method="$3"
        if [[ $method == "PUT" ]]; then
            # PUT
            url=$(echo $1 | sed "s#http://localhost:8100#https://$bigiqIpTarget/mgmt#g")
        else
            # POST
            # we remove the id at the end for the POST
            url=$(echo $1 | sed "s#http://localhost:8100#https://$bigiqIpTarget/mgmt#g" | cut -f1-$(IFS=/; set -f; set -- $1; echo $#) -d"/")
            if [[ $url == *"address-lists"* ]]; then
                # The Address-List must be configured via /mgmt/cm/adc-core/working-config/net/ip-address-lists
                url="https://$bigiqIpTarget/mgmt/cm/adc-core/working-config/net/ip-address-lists"
            fi
        fi
        [[ $debug == "debug" ]] && echo -e "${RED}$method ${NC}in${GREEN} $url ${NC}"
        if [[ $debug == "debug" ]]; then
            curl -s -k -u "$bigiqAdminTarget:$bigiqPasswordTarget" -H "Content-Type: application/json" -X $method -d "$json" $url
        else
            curl -s -k -u "$bigiqAdminTarget:$bigiqPasswordTarget" -H "Content-Type: application/json" -X $method -d "$json" $url > /dev/null
        fi
    }

    snapshotName="snapshot-firewall-$(date +'%Y%d%m-%H%M')"
    
    # Create the snapshot
    echo -e "\n$(date +'%Y-%d-%m %H:%M'): create snapshot${RED} $snapshotName ${NC}"
    snapSelfLink=$(curl -s -H "Content-Type: application/json" -X POST -d "{'name':'$snapshotName'}" http://localhost:8100/cm/firewall/tasks/snapshot-config | jq '.selfLink')

    # Check Snapshot "currentStep": "DONE"
    snapSelfLink=$(echo $snapSelfLink | sed 's#https://localhost/mgmt#http://localhost:8100#g')
    snapSelfLink=${snapSelfLink:1:${#snapSelfLink}-2}
    snapCurrentStep=$(curl -s -H "Content-Type: application/json" -X GET $snapSelfLink | jq '.currentStep')
    while [ "$snapCurrentStep" != "DONE" ]
    do
        [[ $debug == "debug" ]] && "$(date +'%Y-%d-%m %H:%M'): $snapCurrentStep"
        snapCurrentStep=$(curl -s -H "Content-Type: application/json" -X GET $snapSelfLink | jq '.currentStep')
        snapCurrentStep=${snapCurrentStep:1:${#snapCurrentStep}-2}
    done

    era=$(curl -s -H "Content-Type: application/json" -X GET $snapSelfLink | jq '.era')
    echo -e "$(date +'%Y-%d-%m %H:%M'): snapshot${RED} $snapshotName ${NC}creation completed: era =${RED} $era ${NC}"

    # Export policy
    echo -e "$(date +'%Y-%d-%m %H:%M'): policies"
    policy=$(curl -s -H "Content-Type: application/json" -X GET http://localhost:8100/cm/firewall/working-config/policies?era=$era)
    [[ $debug == "debug" ]] && echo $policy | jq .
    send_to_bigiq_target http://localhost:8100/cm/firewall/working-config/policies "$policy" PUT

    policyRuleslink=( $(curl -s -H "Content-Type: application/json" -X GET http://localhost:8100/cm/firewall/working-config/policies?era=$era | jq -r ".items[].rulesCollectionReference.link") )
    for plink in "${policyRuleslink[@]}"
    do
        echo -e "$(date +'%Y-%d-%m %H:%M'): policyRuleslink:${GREEN} $plink ${NC}"
        # Export policy rule
        plink=$(echo $plink | sed 's#https://localhost/mgmt#http://localhost:8100#g')
        policyRules=$(curl -s -H "Content-Type: application/json" -X GET $plink?era=$era)
        [[ $debug == "debug" ]] && echo $policyRules | jq .

        ####################################################
        # Export port list destination
        portListlink=( $(curl -s -H "Content-Type: application/json" -X GET $plink?era=$era | jq -r ".items[].destination.portListReferences[].link") )
        for link in "${portListlink[@]}"
        do
            echo -e "$(date +'%Y-%d-%m %H:%M'):   portListlink dest:${GREEN} $link ${NC}"
            # Export port list
            link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
            if [[ "$link" != "null" ]]; then
                portLists_d=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
                [[ $debug == "debug" ]] && echo $portLists_d | jq .
                send_to_bigiq_target $link "$portLists_d" POST
            fi
        done

        # Export port list source
        portListlink=( $(curl -s -H "Content-Type: application/json" -X GET $plink?era=$era | jq -r ".items[].source.portListReferences[].link") )
        for link in "${portListlink[@]}"
        do
            echo -e "$(date +'%Y-%d-%m %H:%M'):   portListlink src:${GREEN} $link ${NC}"
            # Export port list
            link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
            if [[ "$link" != "null" ]]; then
                portLists_s=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
                [[ $debug == "debug" ]] && echo $portLists_s | jq .
                send_to_bigiq_target $link "$portLists_s" POST
            fi
        done

        # Export address list destination
        addressListlink=( $(curl -s -H "Content-Type: application/json" -X GET $plink?era=$era | jq -r ".items[].destination.addressListReferences[].link") )
        for link in "${addressListlink[@]}"
        do
            echo -e "$(date +'%Y-%d-%m %H:%M'):   addressListlink dest:${GREEN} $link ${NC}"
            # Export address list
            link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
            if [[ "$link" != "null" ]]; then
                addressLists_d=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
                [[ $debug == "debug" ]] && echo $addressLists_d | jq .
                send_to_bigiq_target $link "$addressLists_d" POST
            fi
        done

        # Export address list source
        addressListlink=( $(curl -s -H "Content-Type: application/json" -X GET $plink?era=$era | jq -r ".items[].source.addressListReferences[].link") )
        for link in "${addressListlink[@]}"
        do
            echo -e "$(date +'%Y-%d-%m %H:%M'):   addressListlink src:${GREEN} $link ${NC}"
            # Export address list
            link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
            if [[ "$link" != "null" ]]; then
                addressLists_s=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
                [[ $debug == "debug" ]] && echo $addressLists_s | jq .
                send_to_bigiq_target $link "$addressLists_s" POST
            fi
        done
        ####################################################
        
        ruleListslink=( $(curl -s -H "Content-Type: application/json" -X GET $plink?era=$era | jq -r ".items[].ruleListReference.link") )
        for link in "${ruleListslink[@]}"
        do
            # Export rule list
            echo -e "$(date +'%Y-%d-%m %H:%M'): ruleListslink:${GREEN} $link ${NC}"
            link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
            if [[ "$link" != "null" ]]; then
                ruleLists=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
                [[ $debug == "debug" ]] && echo $ruleLists | jq .
                send_to_bigiq_target $link "$ruleLists" POST
            fi

            # Export rules
            ruleslink=( $(curl -s -H "Content-Type: application/json" -X GET $link?era=$era | jq -r ".rulesCollectionReference.link") )
            for link2 in "${ruleslink[@]}"
            do
                echo -e "$(date +'%Y-%d-%m %H:%M'):  ruleslink:${GREEN} $link2 ${NC}"
                link2=$(echo $link2 | sed 's#https://localhost/mgmt#http://localhost:8100#g')

                ####################################################
                # Export port list destination
                portListlink=( $(curl -s -H "Content-Type: application/json" -X GET $link2?era=$era | jq -r ".items[].destination.portListReferences[].link") )
                for link3 in "${portListlink[@]}"
                do
                    echo -e "$(date +'%Y-%d-%m %H:%M'):   portListlink dest:${GREEN} $link3 ${NC}"
                    # Export port list
                    link3=$(echo $link3 | sed 's#https://localhost/mgmt#http://localhost:8100#g')
                    if [[ "$link3" != "null" ]]; then
                        portLists_d=$(curl -s -H "Content-Type: application/json" -X GET $link3?era=$era)
                        [[ $debug == "debug" ]] && echo $portLists_d | jq .
                        send_to_bigiq_target $link3 "$portLists_d" POST
                    fi
                done

                # Export port list source
                portListlink=( $(curl -s -H "Content-Type: application/json" -X GET $link2?era=$era | jq -r ".items[].source.portListReferences[].link") )
                for link3 in "${portListlink[@]}"
                do
                    echo -e "$(date +'%Y-%d-%m %H:%M'):   portListlink src:${GREEN} $link3 ${NC}"
                    # Export port list
                    link3=$(echo $link3 | sed 's#https://localhost/mgmt#http://localhost:8100#g')
                    if [[ "$link3" != "null" ]]; then
                        portLists_s=$(curl -s -H "Content-Type: application/json" -X GET $link3?era=$era)
                        [[ $debug == "debug" ]] && echo $portLists_s | jq .
                        send_to_bigiq_target $link3 "$portLists_s" POST
                    fi
                done

                # Export address list destination
                addressListlink=( $(curl -s -H "Content-Type: application/json" -X GET $link2?era=$era | jq -r ".items[].destination.addressListReferences[].link") )
                for link3 in "${addressListlink[@]}"
                do
                    echo -e "$(date +'%Y-%d-%m %H:%M'):   addressListlink dest:${GREEN} $link3 ${NC}"
                    # Export address list
                    link3=$(echo $link3 | sed 's#https://localhost/mgmt#http://localhost:8100#g')
                    if [[ "$link3" != "null" ]]; then
                        addressLists_d=$(curl -s -H "Content-Type: application/json" -X GET $link3?era=$era)
                        [[ $debug == "debug" ]] && echo $addressLists_d | jq .
                        send_to_bigiq_target $link3 "$addressLists_d" POST
                    fi
                done

                # Export address list source
                addressListlink=( $(curl -s -H "Content-Type: application/json" -X GET $link2?era=$era | jq -r ".items[].source.addressListReferences[].link") )
                for link3 in "${addressListlink[@]}"
                do
                    echo -e "$(date +'%Y-%d-%m %H:%M'):   addressListlink src:${GREEN} $link3 ${NC}"
                    # Export address list
                    link3=$(echo $link3 | sed 's#https://localhost/mgmt#http://localhost:8100#g')
                    if [[ "$link3" != "null" ]]; then
                        addressLists_s=$(curl -s -H "Content-Type: application/json" -X GET $link3?era=$era)
                        [[ $debug == "debug" ]] && echo $addressLists_s | jq .
                        send_to_bigiq_target $link3 "$addressLists_s" POST
                    fi
                done
                ####################################################

                if [[ "$link2" != "null" ]]; then
                    rules=$(curl -s -H "Content-Type: application/json" -X GET $link2?era=$era)
                    [[ $debug == "debug" ]] && echo $rules | jq .
                    send_to_bigiq_target $link2 "$rules" PUT
                fi
            done 
        done
        send_to_bigiq_target $plink "$policyRules" PUT
    done

    # Delete the snapshot
    echo -e "$(date +'%Y-%d-%m %H:%M'): delete snapshot${RED} $snapshotName ${NC}"
    curl -s -H "Content-Type: application/json" -X DELETE $snapSelfLink > /dev/null

    echo "\n\nElapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"
    echo

    exit 0;
fi