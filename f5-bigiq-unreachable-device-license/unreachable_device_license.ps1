param(
	$bigiq = (Read-Host "Please enter the hostname or IP for your BIG-IQ License server"),
	$bigiqUn = (Read-Host "Please enter the username for your BIG-IQ License server"),
	$bigiqLoginProvider = "local",
	$license_pool = (Read-Host "Please enter the license pool on your BIG-IQ License server that you want to pull from"),
	$bigipAddress = (Read-Host "Please enter the hostname or IP for your BIG-IP VE"),
	$bigipMac = (Read-Host "Please enter the MGMT MAC address for your BIG-IP VE"),
	$hypervisor = "vmware",
	$skuKeyword1 = "LTM",
	$skuKeyword2 = "1G",
	$unitOfMeasure = "yearly",
	$outfilePath = (Get-Location).path,
	$outfile = "$outfilePath/$bigipAddress.bigip.license"
	)

$loginUrl = "https://$($bigiq)/mgmt/shared/authn/login"
$licesneUrl = "https://$($bigiq)/mgmt/cm/device/tasks/licensing/pool/member-management"
$bigiqPwd = (Read-Host "Please enter the password for your BIG-IQ License server" -AsSecureString)

$loginBody = @{}
$loginBody.username = $bigiqUn
$loginBody.password = ConvertFrom-SecureString -SecureString $bigiqPwd -AsPlainText
$loginBody.loginProviderName = $bigiqLoginProvider
$loginBody = ConvertTo-Json $loginBody

$licenseReqBody = @{}
$licenseReqBody.licensePoolName = $license_pool
$licenseReqBody.command = "assign"
$licenseReqBody.address = $bigipAddress
$licenseReqBody.assignmentType = "UNREACHABLE"
$licenseReqBody.macAddress = $bigipMac
$licenseReqBody.hypervisor = $hypervisor
$licenseReqBody.skuKeyword1 = $skuKeyword1
$licenseReqBody.skuKeyword2 = $skuKeyword2
$licenseReqBody.unitOfMeasure = $unitOfMeasure
$licenseReqBody = ConvertTo-Json $licenseReqBody

Write-Warning "This is the payload that will be sent to $bigiq for the license request: $licenseReqBody and then written to $outfile" -WarningAction Inquire

$loginResp = Invoke-RestMethod $loginUrl -Method POST -Body $loginBody -SkipCertificateCheck -ContentType 'application/json'
$X_F5_Auth_Token = $loginResp.token.token
$headers = @{'X-F5-Auth-Token' = $X_F5_Auth_Token}

$licenseReqResp = Invoke-RestMethod $licesneUrl -Method POST -Body $licenseReqBody -Headers $headers -SkipCertificateCheck -ContentType 'application/json'

#Wait until Finished or Failed
Do
{
	sleep 1
	$licenseReqTask = Invoke-RestMethod "$($licesneUrl)/$($licenseReqResp.id)" -Method GET -Headers $headers -SkipCertificateCheck -ContentType 'application/json'
	$licenseReqTask.status
	if ($licenseReqTask.status -eq 'FAILED'){
		break
	}
} While ($licenseReqTask.status -ne 'FINISHED')

if ($licenseReqTask.status -eq 'FAILED'){
	$licenseReqTask.errorMessage
} else {
	$licenseReqTask.licenseText | Out-File $outfile -Force -Confirm:$true
	$licenseReqTask.PSObject.properties.remove('licenseText')
	$licenseReqTask
	Write-Host "license written to $outfile"
}