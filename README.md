# F5 BIG-IQ Product Management Team: Tools

This GitHub Repository is managed by the F5 BIG-IQ Product Management Team.

Bugs and Requests for enhancements can be made by opening an Issue within the repository.

Tools | Description
------------ | -------------
[f5-bigiq-as3-rpm-update](./f5-bigiq-as3-rpm-update) | This script will help you to update AS3 on BIG-IQ. Check [K54909607](https://support.f5.com/csp/article/K54909607) for more details.
[f5-bigiq-do-rpm-update](./f5-bigiq-do-rpm-update) | This script will help you to update DO on BIG-IQ. Check [K54909607](https://support.f5.com/csp/article/K54909607) for more details.
[f5-bigiq-connectivityChecks](./f5-bigiq-connectivityChecks) | This script will run a sequence checks to verify connectivity between BIG-IQ CM, DCD and BIG-IPs.
[f5-bigiq-dcd-health-checks](./f5-bigiq-dcd-health-checks) | This scirpt will run sequence of checks on the BIG-IQ DCD(s).
[f5-bigiq-SSLcertKeyCRLimportTool](https://devcentral.f5.com/articles/automate-import-of-ssl-certificate-key-crl-from-big-ip-to-big-iq-31899) | Automate import of SSL Cert, Key & CRL from BIG-IP to BIG-IQ.<br/>/!\ **This feature is available in BIG-IQ 7.0** /!\
[f5-bigiq-licenseUtilityReport](https://devcentral.f5.com/articles/generation-of-utility-billing-report-using-big-iqs-api-30193) | Utility Billing Report - Generate a usage report for your utility license(s) and provide to F5, Inc. for billing purposes.<br/>/!\ **This feature is available in BIG-IQ 6.1** /!\
[f5-bigiq-f5sanitizeUsageReport](./f5-bigiq-sanitizeUsageReport) | Script to obfuscated IP/MAC addresses and Hostnames from a BIG-IQ JSON report.<br/>/!\ **This feature is available in BIG-IQ 6.1** /!\
[f5-bigiq-syncSharedAFMobjectsTool](./f5-bigiq-syncSharedAFMobjectsTool) | Script to export AFM objects (port lists, address lists, rule lists, policies and policy rules) from 1 BIG-IQ to another.
[f5-bigiq-branchRuleManager](./f5-bigiq-branchRuleManager) | This script will allow you to set advanced expression for branch rules in access policies (per-session and per-request).
[f5-bigiq-deleteOrphanObjects-apm](./f5-bigiq-deleteOrphanObjects-apm) | This script will identify and delete orphan APM objects on BIG-IQ (Access Policy Manager).
[f5-bigiq-ssl-vpn-split-tunneling-and-ipv4exclude-addresses](./f5-bigiq-ssl-vpn-split-tunneling-and-ipv4exclude-addresses) | This script will update IPv4 Exclude Address Space for all the Network Access objects for new IP Address list in the given Access Group on the BIG-IQ.
[f5-bigiq-unreachable-device-license](./f5-bigiq-unreachable-device-license) | This powershell script will help you to get a license for an unreachable BIG-IP device from a License Pool on BIG-IQ.
[f5-bigiq-generate-cert-with-SAN](./f5-bigiq-generate-cert-with-SAN) | This bash script will help you to generate self signed cert with IP address in SAN field.
[f5-bigiq-ansible-runner](./f5-bigiq-ansible-runner) | Run Ansible in a docker container on BIG-IQ.