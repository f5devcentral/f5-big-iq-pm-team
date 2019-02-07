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
# 02/05/2019: v1.2  r.jouhannet@f5.com     Fix port/address nested into rules in policies (not rules lists)
#                                          Implement diff between 2 snapshots to find new AFM object and sync to target BIG-IQ
#                                          Handle DELETE objects
# 02/06/2019: v1.3  r.jouhannet@f5.com     Update sync all objects all at once (speeding up initial import), add logs management
# 02/07/2019: v1.4  r.jouhannet@f5.com     Add name of the objects added/deleted/modified
#                                          Nested port-lists/address-lists supported
#

## DESCRIPTION
# Written for BIG-IQ 5.4 and up.
# Script to export shared AFM objects from 1 BIG-IQ to another.
#
# The script will:
#   - Create a AFM snapshot on BIG-IQ source
#   - INITIAL EXPORT/IMPORT
#      1. Export from the snapshot port lists, address lists, rule lists, policies and policy rules
#         Limiations:
#           - the script is not syncing the iRules, so those will need to be sync manually if any used in the rules.
#           - the script will not import ports/addresses which contains reference to other ports/addresses lists (e.g. ort list nested into a port list)
#      2. Import in BIG-IQ target objects exported previously
#   - FOLLOWING EXPORT/IMPORT
#      1. Make a diff between previous snapshot and current
#      2. Export from the diff new port lists, address lists, rule lists, policies and policy rules
#      3. Import in BIG-IQ target objects exported previously (add/modify/delete)


## INSTRUCTIONS
# The script should be installed under /shared/scripts on the BIG-IQ where you want to export the objects.
# mkdir /shared/scripts
# chmod +x /shared/scripts/sync-shared-afm-objects.sh 
#
# The Target BIG-IQ, login and password need to be specified in the parameters of the script.
# Basic Authentication needs to be turned on on the target BIG-IQ:
# set-basic-auth on
#
# Execute the script for the 1st time manually and make sure the result is correct comparing source and target BIG-IQ.
# Usage: ./sync-shared-afm-objects.sh 10.1.1.4 admin password >> /shared/scripts/sync-shared-afm-objects.log
#
# Reset the script to initial export/import
# Usage: ./sync-shared-afm-objects.sh reset
# 
# Then, schedule the script into the crontab to run every 30min
#
# Make sure you test the script before setting it up in cronab. It is also recommended to test the script in crontab.
# Configure the script in crontab, example every 30min:
# 0,30 * * * * /shared/scripts/sync-shared-afm-objects.sh 10.1.1.4 admin password >> /shared/scripts/sync-shared-afm-objects.log
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

## TROUBLESHOOTING
# To run in debug mode, add "debug" at the end of the command:
# e.g.: ./sync-shared-afm-objects.sh 10.1.1.4 admin password debug >> /shared/scripts/sync-shared-afm-objects.log
# Look at the log sync-shared-afm-objects.log

#########################################################################
# CONFIGURATION
# Directory where is stored the script
home="/shared/scripts"
# Number days we keep the logs
days="30"
#########################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# prevent the script to run twice
already=$(ps -ef | grep "$0" | grep bash | grep -v grep | wc -l)
if [ $already -gt 2 ]; then
    echo "The script is already running. Exiting."
    exit 1
fi

# SECONDS used for total execution time (see end of the script)
SECONDS=0
# Script parameters
bigiqIpTarget=$1
bigiqAdminTarget=$2
bigiqPasswordTarget=$3
debug=$4

# function to send JSON to BIG-IQ target
send_to_bigiq_target () {
    # parameter 1 is the URL, parameter 2 is the JSON payload, parameter 3 is the method (PUT or POST)
    json="$2"
    [[ $debug == "debug" ]] && echo $json | jq .
    # removing "generation": 2, as this is not needed and causing error in the sync
    json=$(echo $json | jq 'del(.generation)')
    echo $json > send.json
    [[ $debug == "debug" ]] && echo $json | jq .
    method="$3"
    if [[ $method == "PUT" || $method == "DELETE" ]]; then
        # PUT
        url=$(echo $1 | sed "s#http://localhost:8100#https://$bigiqIpTarget/mgmt#g")
        if [[ $url == *"address-lists"* ]]; then
            # The Address-List must be configured via /mgmt/cm/adc-core/working-config/net/ip-address-lists
            url=$(echo $url | sed "s#cm/firewall/working-config/address-lists#cm/adc-core/working-config/net/ip-address-lists#g")
        fi
    else
        # POST
        # we remove the id at the end for the POST
        url=$(echo $1 | sed "s#http://localhost:8100#https://$bigiqIpTarget/mgmt#g" | cut -f1-$(IFS=/; set -f; set -- $1; echo $#) -d"/")
        if [[ $url == *"address-lists"* ]]; then
            # The Address-List must be configured via /mgmt/cm/adc-core/working-config/net/ip-address-lists
            url=$(echo $url | sed "s#cm/firewall/working-config/address-lists#cm/adc-core/working-config/net/ip-address-lists#g")
        fi
    fi
    [[ $debug == "debug" ]] && echo -e "${RED}$method ${NC}in${GREEN} $url ${NC}"
    # no need to have a JSON payload for the DELETE
    if [[ $method == "DELETE" ]]; then
        if [[ $debug == "debug" ]]; then
            output=$(curl -s -k -u "$bigiqAdminTarget:$bigiqPasswordTarget" -H "Content-Type: application/json" -X $method  $url)
        else
            output=$(curl -s -k -u "$bigiqAdminTarget:$bigiqPasswordTarget" -H "Content-Type: application/json" -X $method | grep '"code":')
        fi
    else
        if [[ $debug == "debug" ]]; then
            output=$(curl -s -k -u "$bigiqAdminTarget:$bigiqPasswordTarget" -H "Content-Type: application/json" -X $method -d @send.json $url)
        else
            output=$(curl -s -k -u "$bigiqAdminTarget:$bigiqPasswordTarget" -H "Content-Type: application/json" -X $method -d @send.json $url | grep '"code":')
        fi
    fi
    # If error, return 1 (use in the "FOLLOWING EXPORT/IMPORT" part for add/modify in case POST fails, try PUT, might not be necessary
    if [[ $output == *'"code":'* ]]; then
        # Showing error code if any
        echo -e "$(date +'%Y-%d-%m %H:%M'):${RED} ERROR: $output ${NC}"
        return 1
    else
        return 0
    fi
}

if [[  $1 == "reset" ]]; then
    # reset option to allow script to do initial import/export part
    rm $home/previous* 2> /dev/null
    rm $home/send.json 2> /dev/null
    rm $home/nohup.out 2> /dev/null
    echo -e "\nInitial export/import will occure next time the script is launched.\n\n${RED}Please re-launch the script.${NC}\n"
    echo -e "Usage: ${BLUE}./sync-shared-afm-objects.sh 10.1.1.4 admin password [debug] >> /shared/scripts/sync-shared-afm-objects.log${NC}\n"
    exit 1;
elif  [[ -z $1 || -z $2 || -z $3 ]]; then
    echo -e "\nThe script will:\n\t1. Create a AFM snapshot on BIG-IQ source"
    echo -e "\t2. Export from the snapshot port lists, address lists, rule lists, policies and policy rules"
    echo -e "\t3. Import in BIG-IQ target objects exported previously\n"
    echo -e "Note: The first time the script is executed, it does a FULL export/import."
    echo -e "      The following times, the script will do a diff between snapshot and extract the new objects."
    echo -e "      If you need to do again the initial sync, run ./sync-shared-afm-objects.sh reset"
    echo -e "\n${RED}=> No Target BIG-IQ, login and password specified ('set-basic-auth on' on target BIG-IQ)${NC}\n"
    echo -e "Usage: ${BLUE}./sync-shared-afm-objects.sh 10.1.1.4 admin password [debug]${NC}\n"
    exit 1;
else
    snapshotName="snapshot-sync-firewall-$(date +'%Y%d%m-%H%M')"
    
    echo -e "\n$(date +'%Y-%d-%m %H:%M'): BIG-IQ target${RED} $bigiqIpTarget ${NC}"
    # Create the snapshot
    echo -e "$(date +'%Y-%d-%m %H:%M'): create snapshot${RED} $snapshotName ${NC}"
    snapSelfLink=$(curl -s -H "Content-Type: application/json" -X POST -d "{'name':'$snapshotName'}" http://localhost:8100/cm/firewall/tasks/snapshot-config | jq '.selfLink')

    # Check Snapshot "currentStep": "DONE"
    snapSelfLink=$(echo $snapSelfLink | sed 's#https://localhost/mgmt#http://localhost:8100#g')
    snapSelfLink=${snapSelfLink:1:${#snapSelfLink}-2}
    snapCurrentStep=$(curl -s -H "Content-Type: application/json" -X GET $snapSelfLink | jq '.currentStep')
    while [ "$snapCurrentStep" != "DONE" ]
    do
        snapCurrentStep=$(curl -s -H "Content-Type: application/json" -X GET $snapSelfLink | jq '.currentStep')
        snapCurrentStep=${snapCurrentStep:1:${#snapCurrentStep}-2}
        [[ $debug == "debug" ]] && echo -e "$(date +'%Y-%d-%m %H:%M'): $snapCurrentStep"
        [[ $debug == "debug" ]] && sleep 3
    done

    [[ $debug == "debug" ]] && echo $snapSelfLink

    era=$(curl -s -H "Content-Type: application/json" -X GET $snapSelfLink | jq '.era')
    snapshotReferenceLink=$(curl -s -H "Content-Type: application/json" -X GET $snapSelfLink | jq '.snapshotReference.link')
    snapshotReferenceLink=${snapshotReferenceLink:1:${#snapshotReferenceLink}-2}
    echo -e "$(date +'%Y-%d-%m %H:%M'): snapshot${RED} $snapshotName ${NC}creation completed ( era =${RED} $era ${NC})"

    # if previousSnapshotName does not exist, do the initial export/import of the AFM objects (this can take a while, e.g. ~1h30 for 14k objects)
    if [ ! -f $home/previousSnapshotName ]; then
        echo -e "$(date +'%Y-%d-%m %H:%M'):${RED} INITIAL EXPORT/IMPORT${NC}"
        # save snapshot name and link ref
        echo $snapshotName > $home/previousSnapshotName
        echo $snapSelfLink > $home/previousSnapSelfLink
        echo $era > $home/previousEra
        echo $snapshotReferenceLink > $home/previousSnapshotReferenceLink

        # Export port-lists
        array=( $(curl -s -H "Content-Type: application/json" -X GET http://localhost:8100/cm/firewall/working-config/port-lists?era=$era | jq -r ".items[].selfLink" 2> /dev/null) )
        echo -e "$(date +'%Y-%d-%m %H:%M'): port-lists (${#array[@]})"
        for link in "${array[@]}"
        do
            link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
            item=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
            [[ $debug == "debug" ]] && echo $item | jq .
            nestedLink=$(echo $item | jq -r ".items[].portListReferences[].link" 2> /dev/null)
            if [[ $nestedLink == *"http"* ]]; then
                item2=$(curl -s -H "Content-Type: application/json" -X GET $nestedLink?era=$era)
                [[ $debug == "debug" ]] && echo $item2 | jq .
                # added in case of a nested object in a nested object in an object
                nestedLink3=$(echo $item2 | jq -r ".items[].portListReferences[].link" 2> /dev/null)
                if [[ $nestedLink3 == *"http"* ]]; then
                    item3=$(curl -s -H "Content-Type: application/json" -X GET $nestedLink3?era=$era)
                    [[ $debug == "debug" ]] && echo $item3 | jq .
                    name3=$(echo $item3 | jq '.name')
                    echo -e "$(date +'%Y-%d-%m %H:%M'): nested -${RED} $name3 -${GREEN} $nestedLink3 ${NC}"
                    send_to_bigiq_target $nestedLink3 "$item3" POST         
                fi
                name2=$(echo $item2 | jq '.name')
                echo -e "$(date +'%Y-%d-%m %H:%M'): nested -${RED} $name2 -${GREEN} $nestedLink ${NC}"
                send_to_bigiq_target $nestedLink "$item2" POST         
            fi
            name=$(echo $item | jq '.name')
            echo -e "$(date +'%Y-%d-%m %H:%M'):${RED} $name -${GREEN} $link ${NC}"
            send_to_bigiq_target $link "$item" POST         
        done

        # Export address-lists
        array=( $(curl -s -H "Content-Type: application/json" -X GET http://localhost:8100/cm/adc-core/working-config/net/ip-address-lists?era=$era | jq -r ".items[].selfLink" 2> /dev/null) )
        echo -e "$(date +'%Y-%d-%m %H:%M'): address-lists (${#array[@]})"
        for link in "${array[@]}"
        do
            link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
            item=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
            [[ $debug == "debug" ]] && echo $item | jq .
            nestedLink=$(echo $item | jq -r ".items[].addressListReferences[].link" 2> /dev/null)
            if [[ $nestedLink == *"http"* ]]; then
                item2=$(curl -s -H "Content-Type: application/json" -X GET $nestedLink?era=$era)
                [[ $debug == "debug" ]] && echo $item2 | jq .
                # added in case of a nested object in a nested object in an object
                nestedLink3=$(echo $item2 | jq -r ".items[].addressListReferences[].link" 2> /dev/null)
                if [[ $nestedLink3 == *"http"* ]]; then
                    item3=$(curl -s -H "Content-Type: application/json" -X GET $nestedLink3?era=$era)
                    [[ $debug == "debug" ]] && echo $item3 | jq .
                    name3=$(echo $item3 | jq '.name')
                    echo -e "$(date +'%Y-%d-%m %H:%M'): nested -${RED} $name3 -${GREEN} $nestedLink3 ${NC}"
                    send_to_bigiq_target $nestedLink3 "$item3" POST         
                fi
                name2=$(echo $item2 | jq '.name')
                echo -e "$(date +'%Y-%d-%m %H:%M'): nested -${RED} $name2 -${GREEN} $nestedLink ${NC}"
                send_to_bigiq_target $nestedLink "$item2" POST         
            fi
            name=$(echo $item | jq '.name')
            echo -e "$(date +'%Y-%d-%m %H:%M'):${RED} $name -${GREEN} $link ${NC}"
            send_to_bigiq_target $link "$item" POST         
        done

        # Export rule-lists (no nested rule-lists possible)
        array=( $(curl -s -H "Content-Type: application/json" -X GET http://localhost:8100/cm/firewall/working-config/rule-lists?era=$era | jq -r ".items[].selfLink" 2> /dev/null) )
        echo -e "$(date +'%Y-%d-%m %H:%M'): rule-lists (${#array[@]})"
        for link in "${array[@]}"
        do
            link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
            item=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
            [[ $debug == "debug" ]] && echo $item | jq .
            name=$(echo $item | jq '.name')
            echo -e "$(date +'%Y-%d-%m %H:%M'):${RED} $name -${GREEN} $link ${NC}"
            send_to_bigiq_target $link "$item" POST
        done

        # Export policy
        echo -e "$(date +'%Y-%d-%m %H:%M'): policies"
        policy=$(curl -s -H "Content-Type: application/json" -X GET http://localhost:8100/cm/firewall/working-config/policies?era=$era)
        [[ $debug == "debug" ]] && echo $policy | jq .
        send_to_bigiq_target http://localhost:8100/cm/firewall/working-config/policies "$policy" PUT

        # Export policy rules
        array=( $(curl -s -H "Content-Type: application/json" -X GET http://localhost:8100/cm/firewall/working-config/policies?era=$era | jq -r ".items[].rulesCollectionReference.link" 2> /dev/null) )
        for link in "${array[@]}"
        do
            link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
            item=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
            [[ $debug == "debug" ]] && echo $item | jq .
            echo -e "$(date +'%Y-%d-%m %H:%M'): policyRuleslink:${GREEN} $link ${NC}"
            send_to_bigiq_target $plink "$item" PUT
        done
    else
        echo -e "$(date +'%Y-%d-%m %H:%M'):${RED} FOLLOWING EXPORT/IMPORT${NC}"
        # If previousSnapshot file exist, we are going to do a diff between this snapshot and the one new one created at the begining of the script
        # so we don't re-import all the AFM objects but only the diff 
        
        # Retreive previous snapshot name
        previousSnapshotName=$(cat $home/previousSnapshotName)
        previousSnapSelfLink=$(cat $home/previousSnapSelfLink)
        previousEra=$(cat $home/previousEra)
        previousSnapshotReferenceLink=$(cat $home/previousSnapshotReferenceLink)
        # Save current snapshot name and link ref
        echo $snapshotName > $home/previousSnapshotName
        echo $snapSelfLink > $home/previousSnapSelfLink
        echo $era > $home/previousEra
        echo $snapshotReferenceLink > $home/previousSnapshotReferenceLink

        echo -e "$(date +'%Y-%d-%m %H:%M'): previous snapshot${RED} $previousSnapshotName ${NC}( previous era =${RED} $previousEra ${NC})"

        from_snapshot_link=$previousSnapshotReferenceLink
        to_snapshot_link=$snapshotReferenceLink
        [[ $debug == "debug" ]] && echo $previousSnapshotReferenceLink
        [[ $debug == "debug" ]] && echo $snapshotReferenceLink

        diffSelfLink=$(curl -s -H "Content-Type: application/json" -X POST -d '{"description":"Diff pre-deploy-golden and post-deploy-end-corrupt","deviceOrientedDiff":false,"fromStateReference":{"link":"'"$from_snapshot_link"'"},"toStateReference":{"link":"'"$to_snapshot_link"'"},"deviceGroupFilterReferences":null}' http://localhost:8100/cm/firewall/tasks/difference-config | jq '.selfLink')

        # Check diff "status": "FINISHED",
        diffSelfLink=$(echo $diffSelfLink | sed 's#https://localhost/mgmt#http://localhost:8100#g')
        diffSelfLink=${diffSelfLink:1:${#diffSelfLink}-2}
        diffStatus=$(curl -s -H "Content-Type: application/json" -X GET $diffSelfLink | jq '.status')
        while [ "$diffStatus" != "FINISHED" ]
        do 
            diffStatus=$(curl -s -H "Content-Type: application/json" -X GET $diffSelfLink | jq '.status')
            diffStatus=${diffStatus:1:${#diffStatus}-2}
            [[ $debug == "debug" ]] && echo -e "$(date +'%Y-%d-%m %H:%M'): $diffStatus"
            [[ $debug == "debug" ]] && sleep 3
        done

        [[ $debug == "debug" ]] && echo $diffSelfLink

        echo -e "$(date +'%Y-%d-%m %H:%M'): diff completed"

        differenceReferenceLink=$(curl -s -H "Content-Type: application/json" -X GET $diffSelfLink | jq '.differenceReference.link')
        differenceReferenceLink=$(echo $differenceReferenceLink | sed 's#https://localhost/mgmt#http://localhost:8100#g')
        differenceReferenceLink=${differenceReferenceLink:1:${#differenceReferenceLink}-2}
        differenceReferenceLink="$differenceReferenceLink/parts/10000000-0000-0000-0000-000000000000"
        [[ $debug == "debug" ]] && echo $differenceReferenceLink

        echo -e "$(date +'%Y-%d-%m %H:%M'): delete routine"
        ##### DELETE
        # policies
        objectsLinks1=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq '.removed[].fromReference' 2> /dev/null | grep '?generation=' | cut -d\" -f4 | sed 's#?generation=.*##g') )
        [[ $debug == "debug" ]] && echo -e "objectsLinks1:"
        [[ $debug == "debug" ]] && echo ${objectsLinks1[@]} | tr " " "\n"
        # rules
        objectsLinks2=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq '.changed[].nestedDifferences.removed[].fromReference' 2> /dev/null | grep '?generation=' | cut -d\" -f4  | grep policies | grep rules | sed 's#?generation=.*##g') $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq '.removed[].nestedDifferences.removed[].fromReference' 2> /dev/null | grep '?generation=' | cut -d\" -f4 | grep policies | grep rules | sed 's#?generation=.*##g') )
        [[ $debug == "debug" ]] && echo -e "objectsLinks2:"
        [[ $debug == "debug" ]] && echo ${objectsLinks2[@]} | tr " " "\n"
        # rule-lists
        objectsLinks3=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq '.changed[].nestedDifferences.removed[].fromReference' 2> /dev/null  | grep '?generation=' | cut -d\" -f4 | grep rule-lists | sed 's#?generation=.*##g') $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq '.removed[].nestedDifferences.removed[].fromReference' 2> /dev/null | grep '?generation=' | cut -d\" -f4 | grep rule-lists | sed 's#?generation=.*##g') )
        [[ $debug == "debug" ]] && echo -e "objectsLinks3:"
        [[ $debug == "debug" ]] && echo ${objectsLinks3[@]} | tr " " "\n"
        # port-lists
        objectsLinks4=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq '.changed[].nestedDifferences.removed[].fromReference' 2> /dev/null  | grep '?generation=' | cut -d\" -f4 | grep port-lists | sed 's#?generation=.*##g') $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq '.removed[].nestedDifferences.removed[].fromReference' 2> /dev/null | grep '?generation=' | cut -d\" -f4 | grep port-lists | sed 's#?generation=.*##g'))
        [[ $debug == "debug" ]] && echo -e "objectsLinks4:"
        [[ $debug == "debug" ]] && echo ${objectsLinks4[@]} | tr " " "\n"
        # address-lists
        objectsLinks5=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq '.changed[].nestedDifferences.removed[].fromReference' 2> /dev/null  | grep '?generation=' | cut -d\" -f4 | grep address-lists | sed 's#?generation=.*##g') $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq '.removed[].nestedDifferences.removed[].fromReference' 2> /dev/null | grep '?generation=' | cut -d\" -f4 | grep address-lists | sed 's#?generation=.*##g'))
        [[ $debug == "debug" ]] && echo -e "objectsLinks5:"
        [[ $debug == "debug" ]] && echo ${objectsLinks5[@]} | tr " " "\n"
        # merge arrays in the right order: port-lists, address-lists, rule-lists, rules, policies
        objectsLinksRemove=("${objectsLinks4[@]}" "${objectsLinks5[@]}" "${objectsLinks3[@]}" "${objectsLinks2[@]}" "${objectsLinks1[@]}")
        [[ $debug == "debug" ]] && echo -e "\nobjectsLinksRemove:"; 
        [[ $debug == "debug" ]] && echo ${objectsLinksRemove[@]} | tr " " "\n"
        if [ -z "$objectsLinksRemove" ]; then
            [[ $debug == "debug" ]] && echo $objectsLinksRemove
            echo -e "$(date +'%Y-%d-%m %H:%M'):${GREEN} no object(s) to delete${NC}"
        else
            for link in "${objectsLinksRemove[@]}"
            do
                if [[ "$link" != "null" ]]; then
                    link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
                    # Important here, we refer to the previous snapshot for the deleted object => $previousEra
                    object=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$previousEra)
                    [[ $debug == "debug" ]] && echo
                    [[ $debug == "debug" ]] && echo $object
                    name=$(echo $object | jq '.name')
                    echo -e "$(date +'%Y-%d-%m %H:%M'):${RED} $name -${GREEN} $link ${NC}"
                    send_to_bigiq_target $link "$object" DELETE
                fi
            done
        fi

        echo -e "$(date +'%Y-%d-%m %H:%M'): add/modify routine"
        ##### ADD AND MODIFY
        # policies
        objectsLinks1=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq . | grep '?generation=' | cut -d\" -f4 | grep policies | grep -v rules | sed 's#?generation=.*##g' | sort -u) )
        [[ $debug == "debug" ]] && echo -e "objectsLinks1:"
        [[ $debug == "debug" ]] && echo ${objectsLinks1[@]} | tr " " "\n"
        # rules
        objectsLinks2=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq . | grep '?generation=' | cut -d\" -f4 | grep policies | grep rules | sed 's#?generation=.*##g' | sort -u) )
        [[ $debug == "debug" ]] && echo -e "objectsLinks2:"
        [[ $debug == "debug" ]] && echo ${objectsLinks2[@]} | tr " " "\n"
        # rule-lists
        objectsLinks3=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq . | grep '?generation=' | cut -d\" -f4 | grep rule-lists | sed 's#?generation=.*##g' | sort -u ) )
        [[ $debug == "debug" ]] && echo -e "objectsLinks3:"
        [[ $debug == "debug" ]] && echo ${objectsLinks3[@]} | tr " " "\n"
        # port-lists
        objectsLinks4=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq . | grep '?generation=' | cut -d\" -f4 | grep port-lists | sed 's#?generation=.*##g' | sort -u) )
        [[ $debug == "debug" ]] && echo -e "objectsLinks4:"
        [[ $debug == "debug" ]] && echo ${objectsLinks4[@]} | tr " " "\n"
        # address-lists
        objectsLinks5=( $(curl -s -H "Content-Type: application/json" -X GET $differenceReferenceLink | jq . | grep '?generation=' | cut -d\" -f4 | grep address-lists | sed 's#?generation=.*##g' | sort -u) )
        [[ $debug == "debug" ]] && echo -e "objectsLinks5:"
        [[ $debug == "debug" ]] && echo ${objectsLinks5[@]} | tr " " "\n"
        # # merge arrays in the right order: port-lists, address-lists, rule-lists, policies, rules
        objectsLinksAdd=("${objectsLinks4[@]}" "${objectsLinks5[@]}" "${objectsLinks3[@]}" "${objectsLinks1[@]}" "${objectsLinks2[@]}" )
        [[ $debug == "debug" ]] && echo -e "\nobjectsLinksAdd - before removing the deleted:"; 
        [[ $debug == "debug" ]] && echo ${objectsLinksAdd[@]} | tr " " "\n"
        # remove deleted objects from the array
        for del in ${objectsLinksRemove[@]}
        do
            objectsLinksAdd=( "${objectsLinksAdd[@]/$del}" )
        done
        [[ $debug == "debug" ]] && echo -e "\nobjectsLinksAdd - after removing the deleted:"; 
        [[ $debug == "debug" ]] && echo ${objectsLinksAdd[@]} | tr " " "\n"
        if [ -z "$objectsLinksAdd" ]; then
            [[ $debug == "debug" ]] && echo $objectsLinksAdd
            echo -e "$(date +'%Y-%d-%m %H:%M'):${GREEN} no object(s) to add/modify${NC}"
        else
            for link in "${objectsLinksAdd[@]}"
            do
                ## Work around after removing the null in the array, it lefts some extra space iterating on the loop
                if [[ $link == *"http"* && "$link" != "null" ]]; then
                    link=$(echo $link | sed 's#https://localhost/mgmt#http://localhost:8100#g')
                    # Here we can refer to the new snapshot => $era
                    object=$(curl -s -H "Content-Type: application/json" -X GET $link?era=$era)
                    [[ $debug == "debug" ]] && echo
                    [[ $debug == "debug" ]] && echo $object
                    name=$(echo $object | jq '.name')
                    echo -e "$(date +'%Y-%d-%m %H:%M'):${RED} $name -${GREEN} $link ${NC}"
                    send_to_bigiq_target $link "$object" POST
                    [[ $? -ne 0 ]] && send_to_bigiq_target $link "$object" PUT
                fi
            done
        fi

        # delete the old snapshot (we are keeping only lates Snapshot)
        echo -e "$(date +'%Y-%d-%m %H:%M'): delete snapshot${RED} $previousSnapshotName ${NC}"
        curl -s -H "Content-Type: application/json" -X DELETE $previousSnapSelfLink > /dev/null  

        # roll over logs and cleanup
        if [ ! -f $home/sync-shared-afm-objects_$(date +'%Y%d%m').log.gz ]; then
            echo -e "$(date +'%Y-%d-%m %H:%M'): archive/cleanup logs"
            mv $home/sync-shared-afm-objects.log $home/sync-shared-afm-objects_$(date +'%Y%d%m').log 2> /dev/null
            gzip $home/sync-shared-afm-objects_$(date +'%Y%d%m').log 2> /dev/null
            # delete archive older than $days
            find $home/*gz -mtime +$days -type f -delete 2> /dev/null
        fi
    fi

    # cleanup send.json
    rm $home/send.json 2> /dev/null

    # total script execution time
    echo -e "$(date +'%Y-%d-%m %H:%M'): elapsed time:${RED} $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec${NC}"

    exit 0;
fi