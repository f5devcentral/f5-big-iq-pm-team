Installation instructions
-------------------------

Download the script on both Active/Standby BIG-IQ CM.

```
# bash
# mkdir /shared/scripts
# cd /shared/scripts
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-licenseUtilityReport/licenseUtilityReport.pl > licenseUtilityReport.pl
# chmod +x licenseUtilityReport.pl
```

Usage
-----

/!\ **This feature is available in BIG-IQ 6.1** /!\

[Article on devCentral for BIG-IQ 5.4/6.0](https://devcentral.f5.com/articles/generation-of-utility-billing-report-using-big-iqs-api-30193)

[BIG-IQ 6.1 documentation](https://techdocs.f5.com/kb/en-us/products/big-iq-centralized-mgmt/manuals/product/big-iq-managing-big-ip-ve-subscriptions-6-1-0/02.html)

```
# cd /shared/scripts
# ./licenseUtilityReport.pl -k DRLPZ-JISKU-VPUPT-HZMMV-LERVPYQ,GYCWI-FOUEZ-YMWPX-LYROB-PXTKMTG
# ./licenseUtilityReport.pl -c listregkey.csv -r manual
# cat listregkey.csv
  DRLPZ-JISKU-VPUPT-HZMMV-LERVPYQ
  GYCWI-FOUEZ-YMWPX-LYROB-PXTKMTG
```
