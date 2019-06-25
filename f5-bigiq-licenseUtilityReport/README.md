Installation instructions
-------------------------

```
# mkdir /shared/scripts
# cd /shared/scripts
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-licenseUtilityReport/licenseUtilityReport.pl > licenseUtilityReport.pl
# chmod +x licenseUtilityReport.pl
```

Usage
-----

/!\ **This feature is available in BIG-IQ 6.1** /!\

[Look at the article on DevCentral](https://devcentral.f5.com/articles/generation-of-utility-billing-report-using-big-iqs-api-30193) 

```
# cd /shared/scripts
# ./licenseUtilityReport.pl -k DRLPZ-JISKU-VPUPT-HZMMV-LERVPYQ,GYCWI-FOUEZ-YMWPX-LYROB-PXTKMTG
# ./licenseUtilityReport.pl -c listregkey.csv -r manual
# cat listregkey.csv
  DRLPZ-JISKU-VPUPT-HZMMV-LERVPYQ
  GYCWI-FOUEZ-YMWPX-LYROB-PXTKMTG
```