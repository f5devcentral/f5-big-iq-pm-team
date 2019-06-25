Installation instructions
-------------------------

Download the script on both Active/Standby BIG-IQ CM.

```
# mkdir /shared/scripts
# cd /shared/scripts
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-sanitizeUsageReport/f5_sanitize_usage_report.sh > f5_sanitize_usage_report.sh
# chmod +x f5_sanitize_usage_report.sh
```

Usage
-----

/!\ **This feature is available in BIG-IQ 6.1** /!\

```
# cd /shared/scripts
# ./f5_sanitize_usage_report.sh report.json
```