#!/usr/bin/env bash
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

# 06/24/2019: v1.0  r.jouhannet@f5.com    Initial version

# K15612: Connectivity requirements for the BIG-IQ system
# https://support.f5.com/csp/article/K15612
# https://techdocs.f5.com/en-us/bigiq-6-1-0/big-iq-centralized-management-plan-implement-deploy-6-1-0/planning-a-big-iq-centralized-management-deployment.html

# Download the script with curl:
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-connectivityChecks/f5_network_connectivity_checks.sh > f5_network_connectivity_checks.sh

# Requirements for BIG-IQ management and Requirements for BIG-IP device discovery, management, and monitoring
# BIG-IQ CM => BIG-IPs
portcmbigip[0]=443,tcp
portcmbigip[1]=22,tcp
arraylengthportcmbigip=${#portcmbigip[@]}

# Requirements for BIG-IP to BIG-IQ Data Collection Devices (DCD)
# BIG-IPs => BIG-IQ DCDs
portdcdbigip[0]=443,tcp #AVR
portdcdbigip[1]=8008,tcp #FPS
portdcdbigip[2]=8020,tcp #DoS
portdcdbigip[3]=8018,tcp #AFM
portdcdbigip[4]=8514,tcp #ASM
portdcdbigip[5]=9997,tcp #access/IPsec
arraylengthportdcdbigip=${#portdcdbigip[@]}

# Requirements for BIG-IQ management and Data Collection Devices (DCD)
# BIG-IQ CM => DCD
portcmdcd[0]=443,tcp
portcmdcd[1]=22,tcp
portcmdcd[2]=9300,tcp #cluster
portcmdcd[3]=28015,tcp #api
portcmdcd[4]=29015,tcp #cluster
arraylengthportcmdcd=${#portcmdcd[@]}

# Requirements for BIG-IQ HA peers
# BIG-IQ CM <=> CM + Quorum DCD
portha[0]=443,tcp
portha[1]=22,tcp
portha[2]=9300,tcp #cluster
portha[3]=27017,tcp #sync db
portha[4]=28015,tcp #api
portha[5]=29015,tcp #cluster
arraylengthportha=${#portha[@]}

function connection_check() {
  timeout 1 bash -c "cat < /dev/null > /dev/$1/$2/$3" &>/dev/null
  if [  $? == 0 ]; then
    echo -e "Connection to $2 $3 port [$1] succeeded!"
  else
    echo -e "Connection to $2 $3 port [$1] failed!"
  fi
}

# Active/Standby/Quorum DCD (BIG_IQ 7.0 and above)
do_pcs_check() {
  # PCS uses tcp port 2224 for communication
  echo -e "BIG-IQ $1 root password"
  ssh -o StrictHostKeyChecking=no -oCheckHostIP=no -f root@$1 'nohup sh -c "( ( nc -vl 2224 &>/dev/null) & )"'
  # to make sure ssh has returned.
  sleep 1
  nc -zv -w 2 $1 2224 &>/dev/null

  if [[ $? -ne 0 ]]; then
    echo "PCS check Failed for device $1 (TCP 2224)"
  else
    echo "PCS check succeeded for $1 (TCP 2224)"
  fi
}

do_corosync_check() {
  # Corosync sends the data using udp port 5404 and receives the data using udp port 5405
  nc -zvu -p 5404 -w 2 $1 5405 &>/dev/null

  if [[ $? -ne 0 ]]; then
    echo "Corosync check Failed for device $1 (UDP 5404 and 5405)"
  else
    echo "Corosync check succeeded for $1 (UDP 5404 and 5405)"
  fi
}


#################################################################################

PROG=${0##*/}
set -u

echo -e "\nNote: you may use the BIG-IQ CM/DCD self IPs depending on your network architecture."

echo -e "\nBIG-IQ CM Primary IP address:"
read ipcm1

echo -e "\nBIG-IQ HA? (yes/no)"
read ha
if [[ $ha = "yes"* ]]; then
  echo -e "BIG-IQ CM Secondary IP address:"
  read ipcm2
  echo -e "BIG-IQ Quorum DCD IP address (only if Auto-failover HA):"
  read ipquorum
fi

echo

dcdip=()
while IFS= read -r -p "BIG-IQ DCD IP address(es) (end with an empty line): " line; do
    [[ $line ]] || break  # break if line is empty
    dcdip+=("$line")
done

#printf '  «%s»\n' "${dcdip[@]}"
arraylengthdcdip=${#dcdip[@]}

echo

bigipip=()
while IFS= read -r -p "BIG-IP IP address(es) (end with an empty line): " line; do
    [[ $line ]] || break  # break if line is empty
    bigipip+=("$line")
done

#printf '  «%s»\n' "${bigipip[@]}"
arraylengthbigipip=${#bigipip[@]}

#################################################################################

if [[ $arraylengthbigipip -gt 0 ]]; then
  echo -e "\n\n*** TEST BIG-IQ CM => BIG-IPs"
  for (( i=0; i<${arraylengthbigipip}; i++ ));
  do
    for (( j=0; j<${arraylengthportcmbigip}; j++ ));
    do
        connection_check ${portcmbigip[$j]:(-3)} ${bigipip[$i]} ${portcmbigip[$j]%,*} 
    done
  done
fi

if [[ $arraylengthdcdip -gt 0 ]]; then
  echo -e "\n*** TEST BIG-IPs => BIG-IQ DCDs"
  for (( i=0; i<${arraylengthbigipip}; i++ ));
  do
    for (( j=0; j<${arraylengthdcdip}; j++ ));
    do
      cmd=""
      for (( k=0; k<${arraylengthportdcdbigip}; k++ ));
      do
        cmd="connection_check ${portdcdbigip[$k]:(-3)} ${dcdip[$j]} ${portdcdbigip[$k]%,*} ; $cmd"
      done
    done
    echo -e "BIG-IP ${bigipip[$i]} root password"
    ssh -o StrictHostKeyChecking=no -oCheckHostIP=no root@${bigipip[$i]} "$(typeset -f connection_check); $cmd"
    echo
  done

  echo -e "\nNote: FPS uses port 8008, DoS uses port 8020, AFM uses port 8018, ASM uses port 8514 and Access/IPsec uses port 9997.\nIf you are not using those modules, ignore the failure."

  echo -e "\n*** TEST BIG-IQ CM => DCD"
  for (( i=0; i<${arraylengthdcdip}; i++ ));
  do
    for (( j=0; j<${arraylengthportcmdcd}; j++ ));
    do
        connection_check ${portcmdcd[$j]:(-3)} ${dcdip[$i]} ${portcmdcd[$j]%,*}
    done
  done
fi

if [[ $ha = "yes"* ]]; then
  echo -e "\n***HA\n\n*** TEST BIG-IQ CM Primary => CM Secondary"
  for (( j=0; j<${arraylengthportha}; j++ ));
  do
      connection_check ${portha[$j]:(-3)} $ipcm2 ${portha[$j]%,*}
  done

  echo -e "\n*** TEST BIG-IQ CM Secondary => CM Primary"
  cmd=""
  for (( j=0; j<${arraylengthportha}; j++ ));
  do
    cmd="connection_check ${portha[$j]:(-3)} $ipcm1 ${portha[$j]%,*} ; $cmd"
  done
  echo -e "BIG-IQ $ipcm2 root password"
  ssh -o StrictHostKeyChecking=no -oCheckHostIP=no root@$ipcm2 "$(typeset -f connection_check); $cmd"
  echo

  if [ ! -z "$ipquorum" ]; then
    do_pcs_check $ipcm2
    do_pcs_check $ipquorum

    do_corosync_check $ipcm2
    do_corosync_check $ipquorum
  fi
fi

echo -e "\nEnd."