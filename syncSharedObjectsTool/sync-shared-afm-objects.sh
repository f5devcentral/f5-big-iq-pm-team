#!/bin/bash
 
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

# 01/17/2019: v1.0  r.jouhannet@f5.com     Initial version

# Uncomment set command below for code debugging bash
set -x

# Install the script under /shared/scripts in BIG-IQ 1.
# The script will be running on BIG-IQ 1 where the export is done.

if [[ -z $1 || -z $2 || -z $3 ]]; then

    echo -e "\nThe script will:\n\t1. create a AFM snapshot on BIG-IQ 1\n \t2. export from the snapshot port list, address list, rule list, policy, and policy rule\n \t3. import in BIG-IQ 2 objects exported previously"
    echo -e "\n-> No BIG-IQ 2, login, password specified.\n\nUsage: ./sync-shared-afm-objects.sh 10.1.1.6 admin password\n"
    exit 1;

else

    bigiq02Ip=$1
    bigiq02Admin=$2
    bigiq02Password=$3

    snapshotName="snap-$(date +'%H%M')"

    # Create the snapshot
    echo -e "\nCreate snapshot $snapshotName"
    snapSelfLink=$(curl -s -H "Content-Type: application/json" -X POST -d "{'name':'$snapshotName'}" http://localhost:8100/cm/firewall/tasks/snapshot-config | jq '.selfLink')

    # Check Snapshot "currentStep": "DONE"
    snapSelfLink=$(echo $snapSelfLink | sed 's#https://localhost/mgmt#http://localhost:8100#g')
    
    while [ "$snapCurrentStep" = "DONE" ]
    do
        snapCurrentStep=$(curl -s -H "Content-Type: application/json" -X GET $snapSelfLink | jq '.currentStep')
    done

    echo -e "\nsnapshot $snapshotName creation completed"

    # Export port list
    
    # Export  address list
    
    # Export rule list
    
    # Export policy
    
    # Export policy rule


    sleep 10
    # Delete the snapshot
    snapSelfLink=${snapSelfLink:1:${#snapSelfLink}-2}
    curl -s -H "Content-Type: application/json" -X DELETE $snapSelfLink

    exit 0;
fi