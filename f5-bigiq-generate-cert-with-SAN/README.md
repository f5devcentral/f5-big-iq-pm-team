This script generates self-signed certificate with BIG-IQ IP address in SAN field and replaces the default certificate with the newly generated certificate.

Additional details about replacing the default SSL certificate on a BIG-IQ system is available here
https://support.f5.com/csp/article/K52425065

Usage
-----
```
curl -sS https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-generate-cert-with-SAN/generate-self-signed-cert | bash -s <BIG-IQ IP address> <Cert validity in days> <RSA key-length>
For example:
curl -sS https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-generate-cert-with-SAN/generate-self-signed-cert | bash -s 127.0.0.1 730 4192
```

How to view the new certificate?
---
Execute the following command on your local machine
```
openssl s_client -connect <BIG-IQ IP address>:443 -showcerts
```
Make sure the response contains BIG-IQ IP address as shown below. If the response does not contain the BIG-IQ IP address, 
certificate generation may have failed. Follow the steps for rolling back the changes.
```
Certificate chain
 0 s:/C=XX/ST=N/A/L=N/A/O=Self-signed certificate/CN=<BIG-IQ IP address>: Self-signed certificate
   i:/C=XX/ST=N/A/L=N/A/O=Self-signed certificate/CN=<BIG-IQ IP address>: Self-signed certificate
```

Steps for rolling back the changes
-----
Execute the following commands on BIG-IQ terminal
```
mv /config/httpd/conf/ssl.crt/server.crt.default /config/httpd/conf/ssl.crt/server.crt
mv /config/httpd/conf/ssl.key/server.key.default /config/httpd/conf/ssl.key/server.key
tmsh restart sys service webd
```