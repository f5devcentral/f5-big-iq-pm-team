Installation instructions
-------------------------

[K15612: Connectivity requirements for the BIG-IQ system](https://support.f5.com/csp/article/K15612)

Download the script on both Active/Standby BIG-IQ CM(s).

```
# bash
# mkdir /shared/scripts
# cd /shared/scripts
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-connectivityChecks/f5_network_connectivity_checks.sh > f5_network_connectivity_checks.sh
# chmod +x f5_network_connectivity_checks.sh
```

Usage
-----

The script needs to be executed on *both Active/Standby BIG-IQ CM*.

Port 22 is required between BIG-IQ CM(s), DCD(s) and BIG-IP(s) to run the connectivy checks.

```
# cd /shared/scripts
# ./f5_network_connectivity_checks.sh [<BIG-IP sshuser> <BIG-IQ sshuser> <~/.ssh/bigip_priv_key> <~/.ssh/bigiq_priv_key>]
```

BIG-IP/BIG-IQ ssh users and private keys are optionals. **root** user is used by default if nothing is specified and the passwords will be asked.
