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
 
echo -e "\nThe script replaces the IP address with “x.x.x.x”,  MAC address with hash value and the host name with “redacted-hostname” in a JSON report."
 
if [[ -z $1 ]]; then
 
    echo -e "\n-> No JSON report specified.\n\nUsage: ./f5_sanitize_usage_report.sh report.json\n"
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
            macAddressMD5=$(echo $line | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | md5sum | cut -f1 -d' ')
            echo $line | sed -r "s#[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}#$macAddressMD5#g" >>  $1
        elif [[ $line = *"address"* ]]; then
            # if address (IP), replace it with x.x.x.x
            echo $line | sed -r 's#[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]#x.x.x.x#g' >>  $1
        else
            # if no macAddress or address (IP), do nothing
            echo $line >> $1
        fi
    done < $1.orig

    # Replace hostname with redacted-hostnam
    sed -i "/'hostname.*,/c\                           \x27hostname\x27: \x27redacted-hostname\x27," $1
    sed -i "/'hostname.*'/c\                           \x27hostname\x27: \x27redacted-hostname\x27" $1
 
    echo -e "\n-> Backup prior modification: $1.orig"
    echo -e "-> $1 was updated masking IP addresses, MAC addresses and hostnames.\n"
    exit 0;
else
    
    echo -e "\n-> JSON report specified “$1” does not exist. Please check filename specified in the argument.\n"
    ls -l | grep -v total | grep -v $0
    exit 2;
fi
