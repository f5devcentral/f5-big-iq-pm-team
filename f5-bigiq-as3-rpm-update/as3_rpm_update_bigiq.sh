#!/usr/bin/env bash
# Uncomment set command below for code debugging bash
#set -x

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

# 04/07/2020: v1.0  r.jouhannet@f5.com    Initial version
# 04/08/2020: v1.1  r.jouhannet@f5.com    Add $home/ in the if rpm -Uv --force 

home="/home/admin"

if [[ -z $1 ]]; then
    echo -e "\nRead https://support.f5.com/csp/article/K54909607\n"
    echo -e "Usage: $0 <newRPM> <currentRPM>\n"
    echo -e "Note: new AS3 RPM needs to be uploaded in /home/admin.\n"
    echo -e "Example: $0 f5-appsvcs-3.18.0-4.noarch.rpm f5-appsvcs-3.13.2-1.noarch.rpm\n"
    echo "AS3 version currently installed:"
    curl -s http://localhost:8105/shared/appsvcs/info | jq .
    echo
    echo "AS3 RPM in /home/admin:"
    ls -l /home/admin/f5-appsvcs*rpm
    echo
    echo "AS3 RPM in /usr/lib/dco/packages/f5-appsvcs:"
    ls -l /usr/lib/dco/packages/f5-appsvcs/*rpm
    echo
    echo "AS3 rpmFilePath configured in /var/config/rest/config/restjavad.properties.json:"
    cat /var/config/rest/config/restjavad.properties.json | jq .global.appSvcs
    echo
    exit 1
fi

newRPM="$1"
currentRPM="$2" #optional for initial install


if [ -f $home/$newRPM ]; then
    echo -e "\nInstalling latest RPM: ${newRPM}"
    latestVersion=$(curl -s http://localhost:8105/shared/appsvcs/info)
    echo -e "\nAS3 Info: "
    echo "$latestVersion"
    if rpm -Uv --force "$home/$newRPM" ; then
        mount -o remount,rw /usr
        echo "Updating restjavad props to point to new RPM"
        if [ -z "$currentRPM" ]; then
            currentRPM=$newRPM
        fi
        c=$(grep $currentRPM /var/config/rest/config/restjavad.properties.json | wc -l)
        if [[ $c == 1 ]]; then
            sed -i "s/$currentRPM/$newRPM/g" /var/config/rest/config/restjavad.properties.json
            rm -rf /usr/lib/dco/packages/f5-appsvcs/$currentRPM
            mv $home/$newRPM /usr/lib/dco/packages/f5-appsvcs/
        else
            sed -i "s#\"appMappingPollingTimeOutSeconds\" : 180#\"appMappingPollingTimeOutSeconds\" : 180,\"rpmFilePath\" : \"/usr/lib/dco/packages/f5-appsvcs/$newRPM\"#g" /var/config/rest/config/restjavad.properties.json
            mv $home/$newRPM /usr/lib/dco/packages/f5-appsvcs/
        fi
        mount -o remount,ro /usr
        bigstart restart restjavad &
        restartProc=$!
        wait $restartProc
        sleep 5
        bigstart restart restnoded &
        restartProc=$!
        wait $restartProc
        echo "Finished restarting services"
    else
        "Failed to install latest RPM";
        exit 1;
    fi
fi