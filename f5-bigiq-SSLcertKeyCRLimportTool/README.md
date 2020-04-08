Installation instructions
-------------------------

Download the script on both Active/Standby BIG-IQ CM(s).

```
# bash
# mkdir /shared/scripts
# cd /shared/scripts
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-SSLcertKeyCRLimportTool/import-bigip-cert-key-crl.py > import-bigip-cert-key-crl.py
# chmod +x import-bigip-cert-key-crl.py
```

Usage
-----

/!\ **This feature is available in BIG-IQ 7.0** /!\

[Article on devCentral](https://devcentral.f5.com/articles/automate-import-of-ssl-certificate-key-crl-from-big-ip-to-big-iq-31899)

```
# cd /shared/scripts
#  ./import-bigip-cert-key-crl.py <big-ip IP address>
```
