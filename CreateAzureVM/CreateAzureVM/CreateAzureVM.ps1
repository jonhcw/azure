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
	[string]$ServiceName,

	[Parameter(Mandatory=$false, ParameterSetName="NoPrereqs")]
	[string]$ServiceLabel,

	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[Parameter(Mandatory=$True, ParameterSetName="Prereqs")]
	[ValidateScript({ $loc = $_; Get-AzureLocation | ? {$_.Name -match $loc}})]
	[string]$Location,

	[Parameter(Mandatory=$True, ParameterSetName="NoPrereqs")]
	[string]$StorageName,

	[Parameter(Mandatory=$False, ParameterSetName="NoPrereqs")]
	[string]$StorageLabel


)

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

# Working i a blinking message that is to be used when status can be updated somewhat regularly, for example with Jobs and other pollable items
function Write-Working  {
	param ([string]$Message, [int]$CursorHorizontalPosition, [int]$Number, [datetime]$StartTime)
	$startp = $CursorHorizontalPosition
	[Console]::Write("[")

	$startt = [Console]::CursorTop
	$startc = [Console]::ForegroundColor
	$color = "";

	if ($Number % 2 -eq 0) { $color = [Console]::BackgroundColor } else { $color = [System.ConsoleColor]::Yellow }
	[Console]::CursorTop = $startt
	[Console]::ForegroundColor = $color
	[Console]::Write(" WORKING ")
	[Console]::ForegroundColor = $startc

	[Console]::Write("]")

	if ($StartTime) {
		[Console]::Write("] $([int]((get-date) - $StartTime).TotalSeconds)s ")
	} 

	# string format is ugly hack
	if (![string]::IsNullOrEmpty($Message)) {  [Console]::Write([string]::Format("{0, -30}", $Message)) }
	[Console]::CursorLeft = $startp
}

# Waiting is a static message that is to be used when status can't be updated or it is not reasonable, for example when running commands with brief duration such as get-azurevm you don't want to write a job around.
function Write-Waiting {
	Write-Host "[" -NoNewline
	Write-Host -ForegroundColor Cyan " WAITING " -NoNewline
	Write-Host "]" -NoNewline
	[Console]::CursorLeft = ([Console]::CursorLeft) - 11
}

# Write-JobStatus is used with Jobs
function Write-JobStatus {
	param ([int]$JobId)
	$StartTime = get-date
	
	$n = 0
	while (!(get-job -Id $JobId).State.Equals("Completed")) {
		Write-Working -CursorHorizontalPosition ([Console]::CursorLeft) -Number $n -StartTime $StartTime
		$n++
		Start-Sleep -Seconds 1
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

Write-Host "`nCreating Virtual Machine $($VMName)`n"

# If user also needs to create Storage Account / Service
if ($PSCmdlet.ParameterSetName.Equals(("NoPrereqs"))) {
	# Validate Location parameter. This is done here because it's harder to accomplish this complicated script in ValidateScript 
	$AzureLocations = Get-AzureLocation
	if (($AzureLocations | ? {$_.Name.Equals($Location)}) -eq $null) {
		$message = "Invalid AzureLocation provided! Valid options for this subscription are:"
		$AzureLocations | % { $message += "`n  $($_.Name)"}
		Write-Warning $message
		exit
	}

	# Check StorageAccount
	Write-Host ([string]::Format("  {0,-35}", "StorageAccount Status")) -NoNewline
	Write-Waiting
	if ((Get-AzureStorageAccount -WarningAction silentlycontinue | ? {$_.StorageAccountName.Equals($StorageName)}) -ne $null) {
		Write-Success
	} else {
		Write-Failure
		
		# Create StorageAccount
		try {
			Write-Host ([string]::Format("  {0,-35}", "Creating new Storage Account")) -NoNewline
			$job = Start-Job -ScriptBlock {
				param ($sname, $loc, $slabel)
				New-AzureStorageAccount -StorageAccountName $sname -Location $loc -Label $slabel -ErrorAction Stop | Out-Null
				} -ArgumentList $StorageName, $Location, $StorageLabel
		
			Write-JobStatus -Job $job.Id
			$job | Remove-Job
		} catch {
			throw $_.Exception.Message
		}
	}

	# Check service
	Write-Host ([string]::Format("  {0,-35}", "AzureService Status")) -NoNewline
	Write-Waiting
	if ((Get-AzureService -WarningAction silentlycontinue | ? {$_.ServiceName.Equals($ServiceName)}) -ne $null) {
		Write-Success
	} else {
		Write-Failure
		try {
			# Create Azure service
			Write-Host ([string]::Format("  {0,-35}", "Creating new Azure Service")) -NoNewline
			$job = Start-Job -ScriptBlock {
				param ($svcname, $loc, $svclabel)
				New-AzureService -ServiceName $svcname -Location $loc -Label $svclabel | Out-Null
				} -ArgumentList $ServiceName, $Location, $ServiceLabel
		
			Write-JobStatus -Job $job.Id
			$job | Remove-Job
		} catch {
			throw $_.Exception.Message
		} 
	}
}


# Run commands to actually create the VM. Run as a Job so we can print status information
$job = Start-Job -ScriptBlock {
	param ($vname, $vsize, $pw, $user, $svc)
	$ImageName = (get-azurevmimage -ErrorAction Stop| ? {$_.imagename -like "*2012*datacenter*"} |  Sort-Object -Descending publisheddate)[0].imagename
	$VMConfig = New-AzureVMConfig -Name $vname -InstanceSize $vsize -ImageName $ImageName -ErrorAction Stop 
	$ProvisioningConfig = $VMConfig | Add-AzureProvisioningConfig -Windows -Password $pw -AdminUsername $user -ErrorAction Stop 
	$ProvisioningConfig | New-AzureVM -ServiceName $svc -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
	} -ArgumentList $VMName, $VMSize, $Password, $AdminUsername, $ServiceName


Write-Host ([string]::Format("  {0,-35}", "Running New-AzureVM")) -NoNewline
Write-JobStatus -Job $job.Id
$job | Remove-Job

# Wait for the VM status to become "ReadyRole". If there are any error codes, break and report.
Write-Host ([string]::Format("  {0,-35}", "Waiting for 'ReadyRole' status")) -NoNewline
$VM = Get-AzureVM -ServiceName $ServiceName -Name $VMName

$n = 0
$StartDate = Get-Date
while (!$VM.Status.Equals("ReadyRole")) {
	if ($VM.InstanceErrorCode -ne $null) {
		break
	}

	$VM = $VM | Get-AzureVM
	Write-Working -CursorHorizontalPosition ([Console]::CursorLeft) -Number $n -StartTime $StartDate -Message $VM.Status

	Start-Sleep -Seconds 1
	$n++
}

# Not sure what exactly are the indicators that it deployed totally succesfully. I'm assuming errorcode should be null. If it is and Status is ReadyRole, report succesful deployment
if ($VM.InstanceErrorCode -ne $null) {
	Write-Failure
	Write-Error $VM.InstanceErrorCode
}
elseif ($VM.Status.Equals("ReadyRole")) {
	Write-Success
} else {
	Write-Failure
	Write-Error $VM.InstanceErrorCode
	
}
