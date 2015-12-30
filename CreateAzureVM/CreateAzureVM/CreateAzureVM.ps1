#Requires -Modules Azure


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

function Write-Working  {
	param ([int]$CursorHorizontalPosition, [int]$Number)
	$startp = $CursorHorizontalPosition
	[Console]::Write("[")


	$startt = [Console]::CursorTop
	$startc = [Console]::ForegroundColor
	$color = "";

	if ($i % 2 -eq 0) { $color = [Console]::BackgroundCOlor } else { $color = [System.ConsoleColor]::Yellow }
	[Console]::CursorTop = $startt
	[Console]::ForegroundColor = $color
	[Console]::Write(" WORKING ")
	[Console]::ForegroundColor = $startc
	[Console]::Write("] $($i)s")
	[Console]::CursorLeft = $startp

}

function Write-Success {
	Write-Host "[" -NoNewline
	Write-Host -ForegroundColor Green " SUCCESS " -NoNewline
	Write-Host "]"
}

function Write-Failure {
	Write-Host "[" -NoNewline
	Write-Host -ForegroundColor Red " FAILURE " -NoNewline
	Write-Host "]"
}

function Write-Working  {
	param ([int]$CursorHorizontalPosition, [int]$cursorVerticalPosition)
	[Console]::Write("[")
	$startp = $CursorHorizontalPosition + 1
	$startt = [Console]::CursorTop
	$startc = [Console]::ForegroundColor
	for ($i = 0; $i -lt 10; $i++) {
		$color = "";
		if ($i % 2 -eq 0) { $color = [Console]::BackgroundCOlor } else { $color = [System.ConsoleColor]::Yellow }
		[Console]::CursorLeft = $startp
		[Console]::CursorTop = $startt
		[Console]::ForegroundColor = $color
		[Console]::Write(" Working ")
		[Console]::ForegroundColor = $startc
		[Console]::Write("] $($i)s")
		start-sleep -seconds 1
	}
	[Console]::ForegroundColor = $startc
	write-host
}

function Write-JobStatus {
	param ([int]$JobId)

	$n = 0
	while (!(get-job -Id $JobId).State.Equals("Completed")) {
		Write-Working -CursorHorizontalPosition ([Console]::CursorLeft) -Number $n
		$n++
	}
	try { 
		$job | Receive-Job 
	} 
	catch { 
		Write-Failure 
		throw $_.Exception		
	}

	Write-Success
}

# Check whether the Affinity Group exists and create it if it doesn't. Also craete StorageAccount and AzureService
if ((Get-AzureAffinityGroup | ? {$_.Name -match $AffinityGroup}) -eq $null) {
	# Validate Location parameter. This is done here because it's harder to accomplish this complicated script in ValidateScript 
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

	# Create required Services. Inside a try/catch as it's considered a single phase with many steps.
	try {
		# Create Affinity Group
		Write-Host "Creating prerequisite services "
		Write-Host ([string]::Format("  {0,-35}", "Creating new Affinity Group")) -NoNewline 
		$job = Start-Job -ScriptBlock { 
			param($affgroup, $loc, $afflabel)
			New-AzureAffinityGroup -Name $affgroup -Location $loc -Label $afflabel -ErrorAction Stop 
		} -ArgumentList $AffinityGroup, $Location, $AffinityLabel

		Write-JobStatus -Job $job.Id
		$job | Remove-Job

		# Create Storage Account
		Write-Host ([string]::Format("  {0,-35}", "Creating new Storage Account")) -NoNewline
		$job = Start-Job -ScriptBlock {
			param ($sname, $affgroup, $slabel)
			New-AzureStorageAccount -StorageAccountName $sname -AffinityGroup $affgroup -Label $slabel -ErrorAction Stop
			} -ArgumentList $StorageName, $AffinityGroup, $StorageLabel
		
		Write-JobStatus -Job $job.Id
		$job | Remove-Job

		# Create Azure service
		Write-Host ([string]::Format("  {0,-35}", "Creating new Azure Service")) -NoNewline
		$job = Start-Job -ScriptBlock {
			param ($svcname, $loc, $svclabel)
			New-AzureService -ServiceName $svcname -Location $loc -Label $svclabel
			} -ArgumentList $ServiceName, $Location, $ServiceLabel
		
		Write-JobStatus -Job $job.Id
		$job | Remove-Job

		Write-Host -ForegroundColor Green "Prerequisite services created!"
	} catch {
			Write-Failure
			throw $_.Exception.Message
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
while (!([string]($job | get-job).State).Equals("Completed")) {
	Write-Host ($job | get-job).State  -NoNewline
	Start-Sleep -Seconds 1
}

$job | get-job

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
