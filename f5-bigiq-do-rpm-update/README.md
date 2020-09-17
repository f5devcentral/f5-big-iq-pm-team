Installation instructions
-------------------------

Download the script on both Active/Standby BIG-IQ CM(s).

```
bash
mkdir /shared/scripts
cd /shared/scripts
curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-do-rpm-update/do_rpm_update_bigiq.sh > do_rpm_update_bigiq.sh
chmod +x do_rpm_update_bigiq.sh
```

Usage
-----

Consult https://support.f5.com/csp/article/K54909607 before using the tool.

The new DO RPM needs to be uploaded in /home/admin.

```
cd /shared/scripts
./do_rpm_update_bigiq.sh <newRPM>
```
