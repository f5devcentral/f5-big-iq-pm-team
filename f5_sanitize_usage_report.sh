#!/bin/bash
# Uncomment set command below for code debugging bash
#set -x

echo -e "\nThe script replace the IP address with “x.x.x.x” and the host name with “redacted-hostname” in a JSON report."

if [[ -z $1 ]]; then

	echo -e "\n-> No JSON report specified.\n\nUsage: ./f5_sanitize_usage_report.sh report.json\n"
	exit 1;

elif [ -f $1 ]; then
	cp -p $1 $1.orig
	sed -i '/"address":/c\      "address": "x.x.x.x",' $1
	sed -i '/"hostname":/c\      "hostname": "redacted-hostname",' $1

	echo -e "\n-> Backup prior modification: $1.orig"
	echo -e "-> $1 was updated masking address and hostname.\n"
	exit 0;
else
	
	echo -e "\n-> JSON report specified “$1” does not exist. Please check filename specified in the argument.\n"
	ls -l | grep -v total | grep -v $0
	exit 2;
fi
