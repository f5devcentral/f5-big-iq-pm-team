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

# 06/23/2019: v1.0  r.jouhannet@f5.com     Initial version

# K15612: Connectivity requirements for the BIG-IQ system
# https://support.f5.com/csp/article/K15612

# Requirements for BIG-IQ management and Requirements for BIG-IP device discovery, management, and monitoring
# BIG-IQ CM => BIG-IPs
portcmbigip[0]=443
portcmbigip[1]=22
arraylengthportcmbigip=${#portcmbigip[@]}

# Requirements for BIG-IP to BIG-IQ Data Collection Devices (DCD)
# BIG-IPs => BIG-IQ DCDs
portdcdbigip[0]=443 #AVR
portdcdbigip[1]=8008 #FPS
portdcdbigip[2]=8020 #DoS
portdcdbigip[3]=8018 #AFM
portdcdbigip[4]=8514 #ASM
portdcdbigip[5]=9997 #access/IPsec
arraylengthportdcdbigip=${#portdcdbigip[@]}

# Requirements for BIG-IQ management and Data Collection Devices (DCD)
# BIG-IQ CM => DCD
portcmdcd[0]=443
portcmdcd[1]=22
arraylengthportcmdcd=${#portcmdcd[@]}

# Requirements for BIG-IQ HA peers
# BIG-IQ CM <=> CM
portha[0]=443
portha[1]=22
portha[2]=9300 #cluster
portha[3]=27017 #sync db
portha[4]=28015 #api
portha[5]=29015 #cluster
portha[6]=2224 #PCS (BIG_IQ 7.0)
portha[7]=5404 #corosync (BIG_IQ 7.0)
arraylengthportha=${#portha[@]}

# Requirements for BIG-IQ Data Collection Devices (DCD)
# BIG-IQ DCDs <=> DCDs
portdcd[0]=443
portdcd[1]=22
portdcd[2]=9300 #cluster
portdcd[3]=28015 #api
portdcd[4]=29015 #cluster
arraylengthportdcd=${#portdcd[@]}

# NC
nc="nc -z -v -w5"

#################################################################################

PROG=${0##*/}
set -u

echo -e "\nNote: you may use the BIG-IQ CM/DCD self IPs depending on your network architecure."

echo -e "\nBIG-IQ CM Primary IP address:"
read ipcm1

echo -e "\nBIG-IQ HA? (yes/no)"
read ha
if [[ $ha = "yes"* ]]; then
  echo -e "BIG-IQ CM Seconday IP address:"
  read ipcm2
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
        $nc ${bigipip[$i]} ${portcmbigip[$j]} 
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
        cmd="$nc ${dcdip[$j]} ${portdcdbigip[$k]} ; $cmd"
      done
    done
    echo -e "BIG-IP ${bigipip[$i]} root password"
    ssh -o StrictHostKeyChecking=no -oCheckHostIP=no root@${bigipip[$i]} $cmd
    echo
  done

  echo -e "\n*** TEST BIG-IQ CM => DCD"
  for (( i=0; i<${arraylengthdcdip}; i++ ));
  do
    for (( j=0; j<${arraylengthportcmdcd}; j++ ));
    do
        $nc ${dcdip[$i]} ${portcmdcd[$j]}
    done
  done

  #echo -e "\n*** TEST BIG-IQ DCDs <=> DCDs"
  ### TO DO
fi

if [[ $ha = "yes"* ]]; then
  echo -e "\n*** TEST BIG-IQ CM Primary => CM Secondary"
  for (( j=0; j<${arraylengthportha}; j++ ));
  do
      $nc $ipcm2 ${portha[$j]}
  done

  echo -e "\n*** TEST BIG-IQ CM Secondary <= CM Primary"
  cmd=""
  for (( j=0; j<${arraylengthportha}; j++ ));
  do
    cmd="$nc $ipcm1 ${portha[$j]} ; $cmd"
  done
  echo -e "BIG-IQ $ipcm2 root password"
  ssh -o StrictHostKeyChecking=no -oCheckHostIP=no root@$ipcm2 $cmd
  echo
fi

echo -e "End."