Installation instructions
-------------------------

Download the script on both Active/Standby BIG-IQ CM.

```
# mkdir /shared/scripts
# cd /shared/scripts
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-connectivityChecks/f5_network_connectivity_checks.sh > f5_network_connectivity_checks.sh
# chmod +x f5_network_connectivity_checks.sh
```

Usage
-----

The script needs to be executed on both Active/Standby BIG-IQ CM.

```
# cd /shared/scripts
# ./f5_network_connectivity_checks.sh [<BIG-IP sshuser> <BIG-IQ sshuser> <~/.ssh/bigip_priv_key> <~/.ssh/bigiq_priv_key>]
```

BIG-IP/BIG-IQ ssh user and private key are optional. **root** user is used by default if nothing is specify and password will be asked.