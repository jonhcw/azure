
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
		[Console]::Write(" $([int]((get-date) - $StartTime).TotalSeconds)s ")
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
	try { 
		while (!(get-job -Id $JobId).State.Equals("Completed")) {
			if ((get-job -Id $JobId).State.Equals("Failed")) {
				$result = Receive-Job -Id $JobId -ErrorAction SilentlyContinue
				Remove-Job -Id $JobId
				throw $error[0]
			}

			Write-Working -CursorHorizontalPosition ([Console]::CursorLeft) -Number $n -StartTime $StartTime
			$n++
			Start-Sleep -Seconds 1
		}
		Receive-Job -Id $JobId -ErrorAction Stop
	} 
	catch { 
		Write-Failure 
		throw $_.Exception		
	}

	Remove-Job -Id $JobId
	Write-Success
}