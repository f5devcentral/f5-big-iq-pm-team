# Welcome to the F5 BIG-IQ PM team Page

This GitHub Repository is managed by the F5 BIG-IQ Product Management Team.

Scripts | Language | Description
------------ | ------------- | -------------
licenseUtilityReport | Perl | Utility Billing Report - Generate a usage report for your utility license(s) and provide to F5 Networks Inc. for billing purposes.<br/>https://devcentral.f5.com/articles/generation-of-utility-billing-report-using-big-iqs-api-30193<br/>/!\ This feature is available in BIG-IQ 6.1 /!\
f5sanitizeUsageReport | Bash | Script to obfuscated IP/MAC addresses and Hostnames from a BIG-IQ JSON report.<br/>Usage: ./f5_sanitize_usage_report.sh report.json<br/>/!\ This feature is available in BIG-IQ 6.1 /!\
SSLcertKeyCRLimportTool | Python | Automate import of SSL Cert, Key & CRL from BIG-IP to BIG-IQ.<br/>https://devcentral.f5.com/articles/automate-import-of-ssl-certificate-key-crl-from-big-ip-to-big-iq-31899
syncSharedAFMobjectsTool | Bash | Script to export AFM objects (port lists, address lists, rule lists, policies and policy rules) from 1 BIG-IQ to another.<br/>Usage: ./sync-shared-afm-objects.sh <big-iq-ip-target> admin password >> /shared/scripts/sync-shared-afm-objects.log
branchRuleManager | Python | This script will allow you to set advanced expression for branch rules in access policies (per-session and per-request).