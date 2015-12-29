#
# CreateAzureVM.ps1
#

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[string]$VMName,

	[Parameter(Mandatory=$True)]
	[string]$VMSize,

	[Parameter(Mandatory=$True)]
	[String]$Password,

	[Parameter(Mandatory=$True)]
	[string]$AdminUsername,

	[Parameter(Mandatory=$True)]
	[string]$AffinityGroup,

	[Parameter(Mandatory=$True)]
	[string]$ServiceName
)

