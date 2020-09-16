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

# 05/21/2020: v1.0  r.jouhannet@f5.com    Initial version

home="/home/admin"

if [[ -z $1 ]]; then
    echo -e "\nRead https://support.f5.com/csp/article/K54909607\n"
    echo -e "Usage: $0 <newRPM>\n"
    echo -e "Note: new DO RPM needs to be uploaded in /home/admin.\n"
    echo -e "Example: $0 f5-declarative-onboarding-1.11.1-1.noarch.rpm\n"
    echo "DO version currently installed:"
    curl -s http://localhost:8105/shared/declarative-onboarding/info | jq .
    echo
    echo "DO RPM in /home/admin:"
    ls -l /home/admin/f5-declarative-onboarding*rpm
    echo
    exit 1
fi

newRPM="$1"

if [ -f $home/$newRPM ]; then
    echo -e "\nInstalling latest RPM: ${newRPM}"
    latestVersion=$(curl -s http://localhost:8105/shared/declarative-onboarding/info)
    echo -e "\nDO Info: "
    echo "$latestVersion"
    if rpm -Uv --force "$home/$newRPM" ; then
        echo "Restart restjavad..."
        bigstart restart restjavad &
        restartProc=$!
        wait $restartProc
        sleep 5
         echo "Restart restnoded..."
        bigstart restart restnoded &
        restartProc=$!
        wait $restartProc
        echo "Finished restarting services"
    else
        "Failed to install latest RPM";
        exit 1;
    fi
fi