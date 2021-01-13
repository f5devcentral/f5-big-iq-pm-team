Installation instructions
-------------------------

Download the script on both Active/Standby BIG-IQ CM(s).

```
bash
mkdir /shared/scripts
cd /shared/scripts
curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-as3-rpm-update/as3_rpm_update_bigiq.sh > as3_rpm_update_bigiq.sh
chmod +x as3_rpm_update_bigiq.sh
```

Usage
-----

Consult https://support.f5.com/csp/article/K54909607 before using the tool.

The new AS3 RPM needs to be uploaded in /home/admin.

```
cd /shared/scripts
./as3_rpm_update_bigiq.sh <newRPM>
```
