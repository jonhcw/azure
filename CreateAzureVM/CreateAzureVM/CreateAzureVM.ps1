#
# CreateAzureVM.ps1
#

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True, ParameterSetName="Prereqs")]
	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[string]$VMName,

	[Parameter(Mandatory=$True, ParameterSetName="Prereqs")]
	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[ValidateSet("ExtraSmall", "Small", "Medium", "Large", "ExtraLarge")]
	[string]$VMSize,

	[Parameter(Mandatory=$True, ParameterSetName="Prereqs")]
	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[String]$Password,

	[Parameter(Mandatory=$True, ParameterSetName="Prereqs")]
	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[string]$AdminUsername,

	[Parameter(Mandatory=$True, ParameterSetName="Prereqs")]
	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[string]$AffinityGroup,

	[Parameter(Mandatory=$True, ParameterSetName="Prereqs")]
	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]	
	[string]$ServiceName,

	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[string]$ServiceLabel,

	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[ValidateScript({ $loc = $_; Get-AzureLocation | ? {$_.Name -match $loc}})]
	[string]$Location,

	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[string]$AffinityLabel,

	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[string]$StorageName,

	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[string]$StorageLabel


)

# Check whether the Affinity Group exists and create it if it doesn't. Also craete StorageAccount and AzureService
if ((Get-AzureAffinityGroup | ? {$_.Name -match $AffinityGroup}) -eq $null) {
	# Validate parameters
	if ([string]::IsNullOrEmpty($Location)) {
		Write-Warning "AffinityGroup $($AffinityGroup) does not exist, you must specify $Location!"
		exit
	} else {
		$AzureLocations = Get-AzureLocation
		if (($AzureLocations | ? {$_.Name.Equals($Location)}) -eq $null) {
			$message = "Invalid AzureLocation provided! Valid options for this subscription are:"
			$AzureLocations | % { $message += "`n  $($_.Name)"}
			Write-Warning $message
			exit
		}
	}

	try {
		$error.Clear()
		Write-Host "Creating new Affinity Group $($AffinityGroup)"
		New-AzureAffinityGroup -Name $AffinityGroup -Location $Location -Label $AffinityLabel

		Write-Host "Creating new Storage Account $($StorageName)"
		New-AzureStorageAccount -StorageAccountName $StorageName -AffinityGroup $AffinityGroup -Label $StorageLabel

		Write-Host "Creating new Azure Service $($ServiceName)"
		New-AzureService -ServiceName $ServiceName -Location $Location -Label $ServiceLabel

		if ($error[0] -ne $null) {
			exit
		}

		Write-Host "Prerequisite services created!"
	} catch {
			Write-Error "Error creating Affinity group or relevant services! $($_.Exception.Message)"
			exit
	} 
}


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

# Not sure what exactly are the indicators that it deployed totally succesfully. I'm assuming errorcode should be null. If it is and Status is ReadyRole, report succesful deployment
if ($VM.InstanceErrorCode -ne $null) {
	Write-Host "`nVM deployed with errors"
}
elseif ($VM.Status.Equals("ReadyRole")) {
	Write-Host "`nVM deployed succesfully"
} else {
	Write-Host "`nVM deployed with errors"
}
