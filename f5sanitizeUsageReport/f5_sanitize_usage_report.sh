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
 
# Uncomment set command below for code debugging bash
#set -x
 
echo -e "\nThe script replace the IP address with “x.x.x.x”,  MAC address with “xx:xx:xx:00:00:00” and the host name with “redacted-hostname” in a JSON report."
 
if [[ -z $1 ]]; then
 
    echo -e "\n-> No JSON report specified.\n\nUsage: ./f5_sanitize_usage_report.sh report.json\n"
    exit 1;
 
elif [ -f $1 ]; then
    cp -p $1 $1.orig
    sed -i -r 's#[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]#x.x.x.x#g' $1
    sed -i -r 's#[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:#xx:xx:xx:#g' $1
    sed -i "/'hostname.*,/c\                           \x27hostname\x27: \x27redacted-hostname\x27," $1
    sed -i "/'hostname.*'/c\                           \x27hostname\x27: \x27redacted-hostname\x27" $1
 
    echo -e "\n-> Backup prior modification: $1.orig"
    echo -e "-> $1 was updated masking address and hostname.\n"
    exit 0;
else
    
    echo -e "\n-> JSON report specified “$1” does not exist. Please check filename specified in the argument.\n"
    ls -l | grep -v total | grep -v $0
    exit 2;
fi
