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
# 06/25/2019: v1.1  r.jouhannet@f5.com    Add option for user and ssh key for BIG-IP and BIG-IQ
# 07/08/2019: v1.2  r.jouhannet@f5.com    8015 and 29015 ports aren't used in BIG-IQ 7.0 and above

# Usage:
#./f5_network_connectivity_checks.sh [<BIG-IP sshuser> <BIG-IQ sshuser> <~/.ssh/bigip_priv_key> <~/.ssh/bigiq_priv_key>]

# K15612: Connectivity requirements for the BIG-IQ system
# https://support.f5.com/csp/article/K15612
# https://support.f5.com/csp/knowledge-center/software/BIG-IQ?module=BIG-IQ%20Centralized%20Management&version=6.1.0
#  => Planning and Implementing a BIG-IQ Centralized Management Deployment
#    => Open ports required for BIG-IQ system deployment

# Download the script with curl:
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-connectivityChecks/f5_network_connectivity_checks.sh > f5_network_connectivity_checks.sh

# 
bigipsshuser="$1"
bigipsshkey="$3"
if [ -z "$bigipsshuser" ]; then
  bigipsshuser="root"
fi
if [ ! -z "$bigipsshkey" ]; then
  bigipsshkey="-i $bigipsshkey"
fi

bigiqsshuser="$2"
bigiqsshkey="$4"
if [ -z "$bigiqsshuser" ]; then
  bigiqsshuser="root"
fi
if [ ! -z "$bigiqsshkey" ]; then
  bigiqsshkey="-i $bigiqsshkey"
fi

# Requirements for BIG-IQ management and Requirements for BIG-IP device discovery, management, and monitoring
# BIG-IQ CM => BIG-IPs
portcmbigip[0]=443,tcp
portcmbigip[1]=22,tcp # Only required for BIG-IP versions 11.5.0 to 11.6.0
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
# BIG-IQ CM => DCDs
portcmdcd[0]=443,tcp
portcmdcd[1]=22,tcp
portcmdcd[2]=9300,tcp #cluster
arraylengthportcmdcd=${#portcmdcd[@]}

# BIG-IQ DCDs => CM
portdcdcm[0]=9300,tcp #cluster
portdcdcm[1]=28015,tcp #api RethinkDB not for 7.0 and above
portdcdcm[2]=29015,tcp #cluster RethinkDB not for 7.0 and above
arraylengthportdcdcm=${#portdcdcm[@]}

# Requirements for BIG-IQ HA peers
# BIG-IQ CM <=> CM + Quorum DCD
portha[0]=443,tcp
portha[1]=22,tcp
portha[2]=9300,tcp #cluster
portha[3]=27017,tcp #sync db
portha[4]=28015,tcp #api RethinkDB not for 7.0 and above
portha[5]=29015,tcp #cluster RethinkDB not for 7.0 and above
arraylengthportha=${#portha[@]}

# Used timeout /dev/tcp/1.2.3.4/443 for BIG-IP to DCD checks as BIG-IP 14.1 does not have nc.
function connection_check() {
  timeout 1 bash -c "cat < /dev/null > /dev/$1/$2/$3" &>/dev/null
  if [  $? == 0 ]; then
    echo -e "Connection to $2 port $3 [$1] succeeded!"
  else
    echo -e "Connection to $2 port $3 [$1] failed!"
  fi
}

# used for all checks running on BIG-IQ CM, DCD
nc="nc -z -v -w5"

# Active/Standby/Quorum DCD (BIG_IQ 7.0 and above)
do_pcs_check() {
  # Pacemaker uses tcp port 2224 for communication
  echo -e "BIG-IQ $1 $bigiqsshuser password"
  ssh $bigiqsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no -f $bigiqsshuser@$1 'nohup sh -c "( ( nc -vl 2224 &>/dev/null) & )"'
  # to make sure ssh has returned.
  sleep 1
  nc -zv -w 2 $1 2224 &>/dev/null

  if [[ $? -ne 0 ]]; then
    echo "Pacemaker check failed for $1 port 2224 [tcp]"
  else
    echo "Pacemaker check succeeded for $1 port 2224 [tcp]"
  fi
}

do_corosync_check() {
  # Corosync sends the data using udp port 5404 and receives the data using udp port 5405
  nc -zvu -p 5404 -w 2 $1 5405 &>/dev/null

  if [[ $? -ne 0 ]]; then
    echo "Corosync check failed sends port 5404, receives $1 port 5405 [udp]"
  else
    echo "Corosync check succeeded sends port 5404, receives $1 port 5405 [udp]"
  fi
}


#################################################################################

PROG=${0##*/}
set -u

echo -e "\nNote: you may use the BIG-IQ CM/DCD self IPs depending on your network architecture and DCD discovery IP.\nIf you get 'Connection refused', check if the self-ip is used instead of the management interface for discovery IP on the DCDs."

echo -e "\nBIG-IQ CM current IP address (from where you execute this script):"
read ipcm1

echo -e "\nBIG-IQ HA? (yes/no)"
read ha
if [[ $ha = "yes"* ]]; then
  echo -e "BIG-IQ CM secondary IP address (either active or standby depending where you run the script):"
  read ipcm2
  echo -e "BIG-IQ Quorum DCD IP address (only if auto-failover HA is setup):"
  read ipquorum

  echo -e "\nNote: please, run the script from the secondary BIG-IQ CM active or standby."
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
  echo -e "\n\n*** TEST BIG-IQ current CM => BIG-IP(s)"
  for (( i=0; i<${arraylengthbigipip}; i++ ));
  do
    for (( j=0; j<${arraylengthportcmbigip}; j++ ));
    do
        $nc ${bigipip[$i]} ${portcmbigip[$j]%,*} 
    done
  done
  echo -e "\nNote: Port 22 (SSH) is only required for BIG-IP versions 11.5.0 to 11.6.0"
fi

if [[ $arraylengthdcdip -gt 0 && $arraylengthbigipip -gt 0 ]]; then
  echo -e "\n*** TEST BIG-IP(s) => BIG-IQ DCD(s)"
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
    echo -e "BIG-IP ${bigipip[$i]} $bigipsshuser password"
    ssh $bigipsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no $bigipsshuser@${bigipip[$i]} "$(typeset -f connection_check); $cmd"
    echo
  done

  echo -e "\nNote: FPS uses port 8008, DoS uses port 8020, AFM uses port 8018, ASM uses port 8514 and Access/IPsec uses port 9997.\nIf you are not using those modules, ignore the failure."
fi

if [[ $arraylengthdcdip -gt 0 ]]; then
  echo -e "\n*** TEST BIG-IQ current CM => DCD(s)"
  for (( i=0; i<${arraylengthdcdip}; i++ ));
  do
    for (( j=0; j<${arraylengthportcmdcd}; j++ ));
    do
        $nc ${dcdip[$i]} ${portcmdcd[$j]%,*}
    done
  done

  echo -e "\n*** TEST BIG-IQ DCD(s) => current CM"
  for (( i=0; i<${arraylengthdcdip}; i++ ));
  do
    cmd=""
    for (( j=0; j<${arraylengthportdcdcm}; j++ ));
    do
      cmd="$nc $ipcm1 ${portdcdcm[$j]%,*} ; $cmd"
    done
    echo -e "BIG-IQ ${dcdip[$i]} $bigiqsshuser password"
    ssh $bigiqsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no $bigiqsshuser@${dcdip[$i]} $cmd
    echo
  done

  echo -e "\nNote: 28015 and 29015 ports aren't used in BIG-IQ 7.0 and above."
fi

if [[ $ha = "yes"* ]]; then
  echo -e "\n***HA\n\n*** TEST BIG-IQ current CM => secondary CM"
  for (( j=0; j<${arraylengthportha}; j++ ));
  do
      $nc $ipcm2 ${portha[$j]%,*}
  done

  echo -e "\n*** TEST BIG-IQ secondary CM => current CM"
  cmd=""
  for (( j=0; j<${arraylengthportha}; j++ ));
  do
    cmd="$nc $ipcm1 ${portha[$j]%,*} ; $cmd"
  done
  echo -e "BIG-IQ $ipcm2 $bigiqsshuser password"
  ssh $bigiqsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no $bigiqsshuser@$ipcm2 $cmd

  echo -e "\nNote: 28015 and 29015 ports aren't used in BIG-IQ 7.0 and above."

  if [ ! -z "$ipquorum" ]; then
    echo -e "\nNote: Only for BIG-IQ 7.0 and above and if auto-failover HA is setup."
    echo -e "\n*** TEST BIG-IQ current CM => secondary CM"
    do_pcs_check $ipcm2
    echo -e "\n*** TEST BIG-IQ DCD Quorum => current CM"
    do_pcs_check $ipquorum

    echo -e "\n*** TEST BIG-IQ current CM => secondary CM"
    do_corosync_check $ipcm2
    echo -e "\n*** TEST BIG-IQ current CM => DCD Quorum"
    do_corosync_check $ipquorum
  fi
fi

echo -e "\nEnd."