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

# 09/13/2018: v1.0  r.jouhannet@f5.com     Initial version
# 09/17/2018: v1.1  r.jouhannet@f5.com     Fix replace section (e.g. empty)

### Secret password to encrupt the md5 hash
secret_password="changme"

# Uncomment set command below for code debugging bash
#set -x

echo -e "\nThe script replaces the IP address, MAC address and the host name with with encrypted hash value (md5) in a CSV report."
if [[ -z $1 ]]; then

    echo -e "\n-> No CSV report specified.\n\nUsage: ./f5_sanitize_usage_report_historical.sh <full path>/Historical_License_Report.csv\n"
    exit 1;

elif [ -f $1 ]; then
    # Backup original report
    mv $1 $1.orig

    # Setting  internal field separator to null to keep the space
    IFS='';
    # Reading file line by line
    while read -r line; 
    do 
        #echo -e "\nDEBUG $line"
        # skip first line id,sku,uom,granted,revoked,pool_type,pool_regkey,pool_name,TEST,hostname,type,mac_address,hypervisor,tenant,chargeback_tag
        if [[ $line = *"granted"* ]]; then
            echo $line > $1
        else

            # 9 = IP address
            # 10 = hostname
            # 12 = MAC address

            ipAddress=$(echo $line | cut -d ',' -f9)
            if [ ! -z "$ipAddress" ]; then
                ipAddressMD5=$(echo "$ipAddress"  | grep -o -E '[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]' | md5sum | cut -f1 -d' ' | openssl base64 -a -salt -k $secret_password)
            else
                ipAddress="empty"
                ipAddressMD5="empty"
            fi

            hostname=$(echo $line | cut -d ',' -f10)
            if [ ! -z "$hostname" ]; then
                hostnameMD5=$(echo "$hostname"  | awk -F'"' '$2=="hostname"{print $4}' | md5sum | cut -f1 -d' ' | openssl base64 -a -salt -k $secret_password)
            else
                hostname="empty"
                hostnameMD5="empty"
            fi

            macAddress=$(echo $line | cut -d ',' -f12)
            if [ ! -z "$macAddress" ]; then
                macAddressMD5=$(echo "$macAddress" | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | md5sum | cut -f1 -d' ' | openssl base64 -a -salt -k $secret_password)
            else
                macAddress="empty"
                macAddressMD5="empty"
            fi

            #echo -e "\nDEBUG1 before $ipAddress after $ipAddressMD5"
            #echo -e "DEBUG2 before $hostname after $hostnameMD5"
            #echo -e "DEBUG3 before $macAddress after $macAddressMD5"

            echo $line | sed -r "s#$ipAddress#$ipAddressMD5#g" | sed -r "s#$hostname#$hostnameMD5#g" | sed -r "s#$macAddress#$macAddressMD5#g" >> $1
        fi
    done < $1.orig

    # remove empty world with nothing
    sed -i 's/\<empty\>//g' $1

    echo -e "\n-> Backup prior modification: $1.orig"
    echo -e "-> $1 was updated obfuscating with encryption IP addresses, MAC addresses and hostnames.\n"
    exit 0;
else
    
    echo -e "\n-> CSV report specified “$1” does not exist. Please check filename specified in the argument.\n"
    ls -l | grep -v total | grep -v $0
    exit 2;
fi