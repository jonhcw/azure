#
# CreateAzureVM.ps1
#

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[string]$VMName,

	[Parameter(Mandatory=$True)]
	[ValidateSet("ExtraSmall", "Small", "Medium", "Large", "ExtraLarge")]
	[string]$VMSize,

	[Parameter(Mandatory=$True)]
	[String]$Password,

	[Parameter(Mandatory=$True)]
	[string]$AdminUsername,

	[Parameter(Mandatory=$True)]
	[ValidateScript({Get-AzureAffinityGroup -Name $_})]
	[string]$AffinityGroup,

	[Parameter(Mandatory=$True)]
	[ValidateScript({Get-AzureService -ServiceName $_})]
	[string]$ServiceName
)


# Run commands to actually create the VM. Run as a Job so we can print status information
$job = Start-Job -ScriptBlock {
	param ($vname, $vsize, $pw, $user, $group, $svc)
	$ImageName = (get-azurevmimage | ? {$_.imagename -like "*2012*datacenter*"} |  Sort-Object -Descending publisheddate)[0].imagename
	$VMConfig = New-AzureVMConfig -Name $vname -InstanceSize $vsize -ImageName $ImageName
	$ProvisioningConfig = $VMConfig | Add-AzureProvisioningConfig -Windows -Password $pw -AdminUsername $user
	$ProvisioningConfig | New-AzureVM -AffinityGroup $group -ServiceName $svc
	} -ArgumentList $VMName, $VMSize, $Password, $AdminUsername, $AffinityGroup, $ServiceName


# Print status information for New-AzureVM command
Write-Host "Running New-AzureVM" -NoNewline
while (!([string]($job | get-job).State).Equals("Completed") -or !([string]($job | get-job).State).Equals("Failed")) {
	Write-Host "." -NoNewline
	Start-Sleep -Seconds 1
}

Write-Host "`nNew-AzureVM command completed!"

# Wait for the VM status to become "ReadyRole". If there are any error codes, break and report.
$VM = Get-AzureVM -ServiceName $ServiceName -Name $VMName
$VMLastStatus = ""
while (!$VM.Status.Equals("ReadyRole")) {
	if ($VM.InstanceErrorCode -ne $null) {
		Write-Error $VM.InstanceErrorCode
		break
	}

	$VM = $VM | Get-AzureVM
	if ($VMLastStatus -eq $VM.Status) { 
		Write-Host "." -NoNewline
	} else {
		Write-Host "`nVM in status $($VM.Status)" -NoNewline
	}
	$VMLastStatus = $VM.Status
	Start-Sleep -Seconds 1
}

# Not sure what exactly are the indicators that it deployed totally succesfully. I'm assuming

if ($VM.InstanceErrorCode -ne $null) {
	Write-Host "`nVM deployed with errors"
}
elseif ($VM.Status.Equals("ReadyRole")) {
	Write-Host "`nVM deployed succesfully"
} else {
	Write-Host "`nVM deployed with errors"
}
#>