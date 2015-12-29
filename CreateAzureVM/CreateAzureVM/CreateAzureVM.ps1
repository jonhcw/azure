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

$ImageName = (get-azurevmimage | ? {$_.imagename -like "*2012*datacenter*"} |  Sort-Object -Descending publisheddate)[0].imagename
$VMConfig = New-AzureVMConfig -Name $VMName -InstanceSize $VMSize -ImageName $ImageName
$ProvisioningConfig = $VMConfig | Add-AzureProvisioningConfig -Windows -Password $Password -AdminUsername $AdminUsername

Write-Host "Running New-AzureVM command"
$VM = $ProvisioningConfig | New-AzureVM -AffinityGroup $AffinityGroup -ServiceName $ServiceName
Write-Host "Running New-AzureVM command completed!"

$VMLastStatus = ""
while (!$VM.Status.Equals("ReadyRole")) {
	if ($VMName.InstanceErrorCode -ne $null) {
		Write-Error $VMName.InstanceErrorCode
		break
	}

	$VM = $VM | Get-AzureVM
	if ($VMLastStatus -eq $VM.Status) { 
		Write-Host "." -NoNewline
	} else {
		Write-Host "`n$($VM.Status)" -NoNewline
	}
	$VMLastStatus = $VM.Status
	Start-Sleep -Seconds 1
}

if ($VM.Status.Equals("ReadyRole")) {
	Write-Host "VM deployed succesfully"
} else {
	Write-Host "VM deployed with errors"
}
