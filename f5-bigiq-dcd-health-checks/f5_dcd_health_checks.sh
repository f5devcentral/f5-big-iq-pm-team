#!/usr/bin/env bash
# Uncomment set command below for code debugging bash
#set -x

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

# 07/30/2020: v1.0  r.jouhannet@f5.com    Initial version
# 03/31/2021: v1.1  r.jouhannet@f5.com    Updated the script so it works for 8.0

# Usage:
#./f5_dcd_health_checks.sh [<BIG-IQ DCD sshuser>]

# Download the script with curl:
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-dcd-health-checks/f5_dcd_health_checks.sh > f5_dcd_health_checks.sh

#################################################################################

bigiqsshuser="$1"
if [ -z "$bigiqsshuser" ]; then
  bigiqsshuser="root"
fi

PROG=${0##*/}
set -u

logname="f5data_dcd_health_$(date +"%m-%d-%Y_%H%M").log"
rm -f $logname > /dev/null 2>&1
exec 3>&1 1>>$logname 2>&1

echo -e "\n*** CHECK BIG-IQ DCD(s) Health" | tee /dev/fd/3
echo -e "********************************" | tee /dev/fd/3

dcdip=($(restcurl /shared/resolver/device-groups/cm-esmgmt-logging-group/devices | jq '.items[]|{log:.properties.isLoggingNode,add:.address}' -c | grep true | jq -r .add))

version=$(restcurl /shared/identified-devices/config/device-info | jq .version)

echo -e "BIG-IQ version: ${version:1:${#version}-2}\n" | tee /dev/fd/3


echo -e "DCD(s):" | tee /dev/fd/3
echo -e "${dcdip[@]}\n" | tee /dev/fd/3

arraylengthdcdip=${#dcdip[@]}

echo -e "Number of DCD(s): $arraylengthdcdip\n" | tee /dev/fd/3


#################################################################################

if [[ $arraylengthdcdip -gt 0 ]]; then

  for (( i=0; i<${arraylengthdcdip}; i++ ));
  do
    echo -e "# BIG-IQ DCD ${dcdip[$i]} $bigiqsshuser password" | tee /dev/fd/3

    if [[ ${version:1:${#version}-2} = "8.0"*  || ${version:1:${#version}-2} = "8.1"* ]]; then

echo -e "\nHTTPS used.\n" | tee /dev/fd/3

ssh -o StrictHostKeyChecking=no $bigiqsshuser@${dcdip[$i]} <<'ENDSSH'
bash
echo -e "\n-------- localhost:9200/_cat/nodes?h=ip"
curl -s -k https://localhost:9200/_cat/nodes?h=ip | while read ip ; do ping -s120 -ni 0.3 -c 5 $ip ; done 2>&1
echo -e "\n-------- localhost:9200/_cluster/health?pretty"
curl -s -k https://localhost:9200/_cluster/health?pretty
echo -e "\n-------- localhost:9200/_cat/allocation?v"
curl -s -k https://localhost:9200/_cat/allocation?v
echo -e "\n-------- localhost:9200/_cat/nodes?v"
curl -s -k https://localhost:9200/_cat/nodes?v
echo -e "\n-------- localhost:9200/_cat/indices?v"
curl -s -k https://localhost:9200/_cat/indices?v
echo -e "\n-------- localhost:9200/_cat/shards?v"
curl -s -k https://localhost:9200/_cat/shards?v
echo -e "\n-------- localhost:9200/_cat/aliases?v"
curl -s -k https://localhost:9200/_cat/aliases?v
echo -e "\n-------- localhost:9200/_cat/tasks?v"
curl -s -k https://localhost:9200/_cat/tasks?v
echo -e "\n-------- localhost:9200/_all/_settings"
curl -s -k https://localhost:9200/_all/_settings | jq .
echo -e "\n-------- localhost:9200/_settings"
curl -s -k https://localhost:9200/_settings | jq .
echo -e "\n-------- localhost:9200/metadata_dynamic_global_parameters"
curl -s -k https://localhost:9200/metadata_dynamic_global_parameters | jq .
echo -e "\n-------- localhost:9200/metadata_dynamic_global_parameters/_search?size=1000"
curl -s -k https://localhost:9200/metadata_dynamic_global_parameters/_search?size=1000 | jq .
ENDSSH

    else

echo -e "\nHTTP used.\n" | tee /dev/fd/3

ssh -o StrictHostKeyChecking=no $bigiqsshuser@${dcdip[$i]} <<'ENDSSH'
bash
echo -e "\n-------- localhost:9200/_cat/nodes?h=ip"
curl -s localhost:9200/_cat/nodes?h=ip | while read ip ; do ping -s120 -ni 0.3 -c 5 $ip ; done 2>&1
echo -e "\n-------- localhost:9200/_cluster/health?pretty"
curl -s localhost:9200/_cluster/health?pretty
echo -e "\n-------- localhost:9200/_cat/allocation?v"
curl -s localhost:9200/_cat/allocation?v
echo -e "\n-------- localhost:9200/_cat/nodes?v"
curl -s localhost:9200/_cat/nodes?v
echo -e "\n-------- localhost:9200/_cat/indices?v"
curl -s localhost:9200/_cat/indices?v
echo -e "\n-------- localhost:9200/_cat/shards?v"
curl -s localhost:9200/_cat/shards?v
echo -e "\n-------- localhost:9200/_cat/aliases?v"
curl -s localhost:9200/_cat/aliases?v
echo -e "\n-------- localhost:9200/_cat/tasks?v"
curl -s localhost:9200/_cat/tasks?v
echo -e "\n-------- localhost:9200/_all/_settings"
curl -s localhost:9200/_all/_settings | jq .
echo -e "\n-------- localhost:9200/_settings"
curl -s localhost:9200/_settings | jq .
echo -e "\n-------- localhost:9200/metadata_dynamic_global_parameters"
curl -s localhost:9200/metadata_dynamic_global_parameters | jq .
echo -e "\n-------- localhost:9200/metadata_dynamic_global_parameters/_search?size=1000"
curl -s localhost:9200/metadata_dynamic_global_parameters/_search?size=1000 | jq .
ENDSSH

    fi

    echo
  done

fi

echo -e "\nBIG-IQ DCD cluster status:" | tee /dev/fd/3
cat $logname | grep -B 1 '"status"' | tee /dev/fd/3

echo -e "\nBIG-IQ DCD red indice(s) if any:" | tee /dev/fd/3
cat $logname | grep red | grep -v BIG-IQ | tee /dev/fd/3
c=$(cat $logname | grep red | grep -v BIG-IQ | wc -l)
if [[ $c  == 0 ]]; then
       echo -e "n/a" | tee /dev/fd/3
fi

echo -e "\nOutput located in $logname\n" | tee /dev/fd/3