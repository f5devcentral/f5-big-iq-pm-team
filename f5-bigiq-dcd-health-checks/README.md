Installation instructions
-------------------------

[K15612: Connectivity requirements for the BIG-IQ system](https://support.f5.com/csp/article/K15612)

Download the script on both Active/Standby BIG-IQ CM(s).

```
# bash
# mkdir /shared/scripts
# cd /shared/scripts
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-dcd-health-checks/f5_dcd_health_checks.sh > f5_dcd_health_checks.sh
# chmod +x f5_dcd_health_checks.sh
```

Usage
-----

The script needs to be executed on *Active BIG-IQ CM*.

```
# cd /shared/scripts
#./f5_dcd_health_checks.sh [<BIG-IQ DCD sshuser>]
```

BIG-IQ DCD ssh users is optional. **root** user is used by default if nothing is specified and the passwords will be asked.