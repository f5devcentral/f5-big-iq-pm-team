Installation instructions
-------------------------

Download the script on BIG-IQ CM.

```
curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-generate-cert-with-SAN/generate-self-signed-cert > f5-generate-self-signed-cert.sh
chmod +x f5-generate-self-signed-cert.sh
```

Usage
-----

```
curl -sS https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-generate-cert-with-SAN/generate-self-signed-cert | bash -s <BIG-IQ IP address> <Cert validity in days> <RSA key-length>
For example:
https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-generate-cert-with-SAN/generate-self-signed-cert | bash -s 127.0.0.1 730 4192
```