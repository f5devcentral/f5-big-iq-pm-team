Usage
-----

```
curl -sS https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-generate-cert-with-SAN/generate-self-signed-cert | bash -s <BIG-IQ IP address> <Cert validity in days> <RSA key-length>
For example:
curl -sS https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-generate-cert-with-SAN/generate-self-signed-cert | bash -s 127.0.0.1 730 4192
```