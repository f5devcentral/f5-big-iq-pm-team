#!/usr/bin/env bash
# Uncomment set command below for code debugging bash
#set -x

#################################################################################
# Copyright 2021 by F5 Networks, Inc.
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
# 07/20/2019: v1.3  r.jouhannet@f5.com    Add note dcd to big-ip before 13.1.0.5 curl -k -u admin:password https://<bigipaddress>/mgmt/shared/echo
# 01/08/2019: v1.4  r.jouhannet@f5.com    Toku port 27017 removed for 7.1 and above, replaced with 5432 for HA replication
# 15/04/2020: v1.5  r.jouhannet@f5.com    Add DCD(s) to DCD(s) checks. Minor output reformating
# 02/07/2020: v1.6  r.jouhannet@f5.com    Remove DCD to DCD ports 28015 and 29015 as it's for 6.1.
# 08/28/2020: v1.7  r.jouhannet@f5.com    Split Management IP and Discovery IP for CM
#                                         Split Discovery/Listener and Data Collection IP for DCD
# 09/04/2020: v1.8  r.jouhannet@f5.com    Automatically get eth0 BIG-IQ CM. Update note for HA, improve user inputs.
# 10/12/2020: v1.9  r.jouhannet@f5.com    Add latency checks
# 04/02/2021: v2.0  r.jouhannet@f5.com    Add support BIG-IQ 8.0

# Usage:
#./f5_network_connectivity_checks.sh [<BIG-IP sshuser> <BIG-IQ sshuser> <~/.ssh/bigip_priv_key> <~/.ssh/bigiq_priv_key>]

# K15612: Connectivity requirements for the BIG-IQ system
# https://support.f5.com/csp/article/K15612
# https://support.f5.com/csp/knowledge-center/software/BIG-IQ?module=BIG-IQ%20Centralized%20Management&version=7.1.0
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
# BIG-IQ DCDs => BIG-IPs
# curl -k -u admin:password https://<bigipaddress>/mgmt/shared/echo

# Requirements for BIG-IQ management and Data Collection Devices (DCD)
# BIG-IQ CM => DCDs
portcmdcd[0]=443,tcp
portcmdcd[1]=22,tcp
portcmdcd[2]=9300,tcp #cluster
arraylengthportcmdcd=${#portcmdcd[@]}

# BIG-IQ DCDs => CM
portdcdcm[0]=9300,tcp #cluster
#portdcdcm[1]=28015,tcp #api RethinkDB for <= 6.1
#portdcdcm[2]=29015,tcp #cluster RethinkDB <= 6.1
arraylengthportdcdcm=${#portdcdcm[@]}

# BIG-IQ DCD <=> DCD
portdcddcd[0]=9300,tcp #cluster
arraylengthportdcddcd=${#portdcddcd[@]}

# Requirements for BIG-IQ HA peers
# BIG-IQ CM <=> CM + Quorum DCD
portha[0]=443,tcp
portha[1]=22,tcp
portha[2]=9300,tcp #cluster
portha[3]=27017,tcp #sync db toku <= 7.0
portha[4]=5432,tcp #sync db Postgres HA replication >= 7.1
#portha[5]=28015,tcp #api RethinkDB HA replication <= 6.1
#portha[6]=29015,tcp #cluster RethinkDB <= 6.1
arraylengthportha=${#portha[@]}

# Used timeout /dev/tcp/1.2.3.4/443 for BIG-IP to DCD checks as BIG-IP 14.1 does NOT have nc.
function connection_check() {
  timeout 1 bash -c "cat < /dev/null > /dev/$1/$2/$3" &>/dev/null
  if [  $? == 0 ]; then
    echo -e "Connection to $2 port $3 [$1] succeeded!"
  else
    echo -e "Connection to $2 port $3 [$1] failed!"
  fi
}

# Network Tool to test connectivity
nc="nc -v -w 2"

version=$(curl -s http://localhost:8100/shared/resolver/device-groups/cm-shared-all-big-iqs/devices?\$select=version | jq .items[0].version)
version=${version:1:${#version}-2}

#################################################################################

PROG=${0##*/}
set -u

echo -e "\nBIG-IQ Version: $version"

echo -e "\nFollow the prompts to specify the IP addresses for each component in your BIG-IQ solution."

echo - e "\nNote: If you get 'Connection refused', check to see if either your BIG-IQs or DCDs are using a self-IP address instead of the management interface for discovery."
echo - e "Depending on your network architecture and the discovery addresses.you chose, you might need to use the BIG-IQ CM and DCD self IP addressses here."

echo -e "\nBIG-IQ CM IP address(s) list:"
ip addr show | grep -w inet | grep -v tmm | grep global

echo -e "\nBIG-IQ CM Management IP address (eth0):"
#read ipcm1m
ipcm1m=$(ip addr show | grep -w inet | grep -v tmm | grep global | grep -E 'eth0|mgmt' | awk '{print $2}' | head -c -4)
echo $ipcm1m

echo -e "\nDiscovery IP address for this BIG-IQ? (If the BIG-IQ uses the eth0 management IP address for discovery, leave empty and hit Enter) "
read ipcm1d

if [[ -z $ipcm1d ]]; then
  ipcm1d=$ipcm1m
  echo -e "Discovery IP address is Management IP address ($ipcm1d)"
fi

echo -e "\nBIG-IQ HA? Type y for yes, n for no (the default)."
read ha
if [[ $ha = "yes"* ||  $ha = "y"* ]]; then
  echo -e "Management IP address for the HA peer:"
  read ipcm2m
  echo -e "Management IP address for the BIG-IQ Quorum DCD? (only if auto-failover HA is set up. If not needed, leave empty and hit Enter) "
  read ipquorum

  echo -e "\nNote: You must run this script from both the primary and the secondary HA BIG-IQ CMs."
else
  echo -e "No HA."
fi

echo

# Discovery/Listener Address (eth0 or eth1 or eth2)
dcdip1=()
while IFS= read -r -p "BIG-IQ DCD Discovery/Listener IP address(es)? (If not needed, leave empty and hit Enter) " line; do
    [[ $line ]] || break  # break if line is empty
    dcdip1+=("$line")
done

echo

# Data Collection IP Address (eth0 or eth1 or eth2)
dcdip2=()
while IFS= read -r -p "BIG-IQ DCD Data Collection IP address(es)? (If not needed, leave empty and hit Enter.) " line; do
    [[ $line ]] || break  # break if line is empty
    dcdip2+=("$line")
done

#printf '  «%s»\n' "${dcdip1[@]}"
arraylengthdcdip=${#dcdip1[@]}

echo

bigipip=()
while IFS= read -r -p "Discovery IP address for BIG-IP? (If not needed, leave empty and hit Enter.) " line; do
    [[ $line ]] || break  # break if line is empty
    bigipip+=("$line")
done

echo -e "\nDo you want to test the latency? (ICMP protocol open required) Type y for yes, n for no (the default)."
read latency

#printf '  «%s»\n' "${bigipip[@]}"
arraylengthbigipip=${#bigipip[@]}

#################################################################################

if [[ $arraylengthbigipip -gt 0 ]]; then
  echo -e "\n\n*** TEST BIG-IQ primary CM => BIG-IP(s)"
  echo -e "*****************************************"
  for (( i=0; i<${arraylengthbigipip}; i++ ));
  do
    for (( j=0; j<${arraylengthportcmbigip}; j++ ));
    do
        echo -e "\nCheck for ${bigipip[$i]} port ${portcmbigip[$j]}"
        cat /dev/null | $nc ${bigipip[$i]} ${portcmbigip[$j]%,*} 2>&1 | grep -v Version | grep -v received | grep -v SSH
    done
    if [[ $latency = "yes"* || $latency = "y"* ]]; then
      echo -e "\nLatency: $(ping ${bigipip[$i]} -c 100 -i 0.010  | tail -1)"
      echo
    fi
  done
  echo -e "Note: Port 22 (SSH) is only required for BIG-IP versions 11.5.0 to 11.6.0"

fi

if [[ $arraylengthdcdip -gt 0 && $arraylengthbigipip -gt 0 ]]; then
  echo -e "\n*** TEST BIG-IP(s) => BIG-IQ DCD(s)"
  echo -e "***********************************"
  for (( i=0; i<${arraylengthbigipip}; i++ ));
  do
    for (( j=0; j<${arraylengthdcdip}; j++ ));
    do
      cmd=""
      for (( k=0; k<${arraylengthportdcdbigip}; k++ ));
      do
        cmd="connection_check ${portdcdbigip[$k]:(-3)} ${dcdip1[$j]} ${portdcdbigip[$k]%,*} ; $cmd"
      done
      if [[ $latency = "yes"* || $latency = "y"* ]]; then
        cmd="$cmd echo -e \"\nLatency: $(ping ${dcdip1[$j]} -c 100 -i 0.010  | tail -1)\""
      fi
    done
    echo -e "BIG-IP ${bigipip[$i]} $bigipsshuser password"
    ssh $bigipsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no $bigipsshuser@${bigipip[$i]} "$(typeset -f connection_check); $cmd"
    echo
  done

  echo -e "Note: FPS uses port 8008, DoS uses port 8020, AFM uses port 8018, ASM uses port 8514 and Access/IPsec uses port 9997.\nIf you are not using those modules, ignore the failure."
fi

if [[ $arraylengthdcdip -gt 0 ]]; then
  echo -e "\n*** TEST BIG-IQ primary CM => DCD(s)"
  echo -e "************************************"
  for (( i=0; i<${arraylengthdcdip}; i++ ));
  do
    for (( j=0; j<${arraylengthportcmdcd}; j++ ));
    do
        echo -e "\nCheck for ${dcdip2[$i]} port ${portcmdcd[$j]}"
        cat /dev/null | $nc ${dcdip2[$i]} ${portcmdcd[$j]%,*} 2>&1 | grep -v Version | grep -v received | grep -v SSH
    done
    if [[ $latency = "yes"* || $latency = "y"* ]]; then
      echo -e "\nLatency: $(ping ${dcdip2[$i]} -c 100 -i 0.010  | tail -1)"
      echo
    fi
  done

  echo -e "\n*** TEST BIG-IQ DCD(s) => primary CM"
  echo -e "************************************"
  for (( i=0; i<${arraylengthdcdip}; i++ ));
  do
    cmd=""
    for (( j=0; j<${arraylengthportdcdcm}; j++ ));
    do
      cmd="echo -e \"\nCheck for $ipcm1d port ${portdcdcm[$j]}\"; cat /dev/null | $nc $ipcm1d ${portdcdcm[$j]%,*} 2>&1 | grep -v Version | grep -v received | grep -v SSH; $cmd"
    done
    echo -e "BIG-IQ DCD ${dcdip2[$i]} $bigiqsshuser password"
    ssh $bigiqsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no $bigiqsshuser@${dcdip2[$i]} $cmd
    echo
  done

  #echo -e "Note: 28015 and 29015 ports used only <= 6.1"

  if [[ $arraylengthdcdip -gt 1 ]]; then
    echo -e "\n*** TEST BIG-IQ DCD(s) => DCD(s)"
    echo -e "********************************"
    set -- ${dcdip2[@]}
    for a; do
        shift
        for b; do
            echo -e "* DCD $a to DCD $b"
            cmd=""
            for (( j=0; j<${arraylengthportdcddcd}; j++ ));
            do
              cmd="echo -e \"\nCheck for $b port ${portdcddcd[$j]}\"; cat /dev/null | $nc $a ${portdcddcd[$j]%,*} 2>&1 | grep -v Version | grep -v received | grep -v SSH; $cmd"
            done
            echo -e "BIG-IQ DCD $a $bigiqsshuser password"
            ssh $bigiqsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no $bigiqsshuser@$b $cmd
            echo
            if [[ $latency = "yes"* || $latency = "y"* ]]; then
              echo -e "\nLatency: $(ssh $bigiqsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no $bigiqsshuser@$b "ping $a -c 100 -i 0.010  | tail -1")"
              echo
            fi
            echo -e "* DCD $b to DCD $a"
            cmd=""
            for (( j=0; j<${arraylengthportdcddcd}; j++ ));
            do
              cmd="echo -e \"\nCheck for $a port ${portdcddcd[$j]}\"; cat /dev/null | $nc $a ${portdcddcd[$j]%,*} 2>&1 | grep -v Version | grep -v received | grep -v SSH; $cmd"
            done
            echo -e "BIG-IQ DCD $b $bigiqsshuser password"
            ssh $bigiqsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no $bigiqsshuser@$a $cmd
            echo
        done
    done
  fi

fi

if [[ $ha = "yes"*  || $ha = "y"* ]]; then
  echo -e "\n*** High Availability\n\n*** TEST BIG-IQ primary CM => secondary CM"
  echo -e "****************************************************"
  for (( j=0; j<${arraylengthportha}; j++ ));
  do
      echo -e "\nCheck for $ipcm2m port ${portha[$j]}"
      cat /dev/null | $nc $ipcm2m ${portha[$j]%,*} 2>&1 | grep -v Version | grep -v received | grep -v SSH
  done
  if [[ $latency = "yes"* || $latency = "y"* ]]; then
    echo -e "\nLatency: $(ping $ipcm2m -c 100 -i 0.010  | tail -1)"
  fi

  echo -e "\nNote: \n- 27017 port used only <= 7.0.\n- 5432 port used only >= 7.1"

  echo -e "\n*** TEST BIG-IQ secondary CM => primary CM"
  echo -e "******************************************"
  cmd=""
  for (( j=0; j<${arraylengthportha}; j++ ));
  do
    cmd="echo -e \"\nCheck for $ipcm1m port ${portha[$j]}\"; cat /dev/null | $nc $ipcm1m ${portha[$j]%,*} 2>&1 | grep -v Version | grep -v received | grep -v SSH; $cmd"
  done
  echo -e "BIG-IQ CM $ipcm2m $bigiqsshuser password"
  ssh $bigiqsshkey -o StrictHostKeyChecking=no -o CheckHostIP=no $bigiqsshuser@$ipcm2m $cmd

  #echo -e "\nNote: 28015 and 29015 ports used only <= 6.1"

  echo -e "\nNote: \n- 27017 port used only <= 7.0.\n- 5432 port used only >= 7.1"

  # Active/Standby/Quorum DCD (BIG_IQ 7.0 and above)
  if [ ! -z "$ipquorum" ]; then
    echo -e "\nNote: Only for <= 7.0 and if auto-failover HA is setup."
    # Pacemaker uses tcp port 2224 for communication
    echo -e "\n*** TEST BIG-IQ primary CM => secondary CM"
    echo -e "******************************************"
    echo -e "Make sure traffic is open from $ipcm1m to $ipcm2m port 2224 [tcp].\n"
    echo -e "\n*** TEST BIG-IQ DCD Quorum => primary CM"
    echo -e "******************************************"
    echo -e "Make sure traffic is open from $ipcm1m to $ipquorum port 2224 [tcp].\n"

    # Corosync
    echo -e "\n*** TEST BIG-IQ primary CM => secondary CM"
    echo -e "******************************************"
    echo -e "Make sure traffic is open from $ipcm1m port 5404 to $ipcm2m port 5405 [udp].\n"
    echo -e "\n*** TEST BIG-IQ primary CM => DCD Quorum"
    echo -e "******************************************"
    echo -e "Make sure traffic is open from $ipcm1m port 5404 to $ipquorum port 5405 [udp].\n"
  fi
fi

echo -e "\nPlease make sure to run this check from both the primary and secondary BIG-IQ CM."

echo -e "\nAdditionally, If you are managing version 13.1.0.5 or earlier BIG-IP devices, you need to login to one of the DCDs in the cluster and type the following command: curl -k -u admin:password https://<bigipaddress>/mgmt/shared/echo"

echo -e "\nPlease, also visit https://support.f5.com/csp/article/K15612"

echo -e "\nEnd."