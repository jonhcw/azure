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

$VMConfig = New-AzureVMConfig -Name $VMName -InstanceSize $VMSize -ImageName a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-Datacenter-20151120-en.us-127GB.vhd
$VMConfig | Add-AzureProvisioningConfig -Windows -Password $Password -AdminUsername $AdminUsername | New-AzureVM -AffinityGroup $AffinityGroup -ServiceName $ServiceName