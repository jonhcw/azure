#Requires -Modules Azure

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[string]$VMName,

	[Parameter(Mandatory=$True)]
	[string]$ServiceName,

	[Parameter(Mandatory=$True)]
	[string]$Username,

	[Parameter(Mandatory=$True)]
	[string]$Password

)

$ErrorActionPreference = 'Stop'

Write-Host "Deploying 7-Zip to $($VMName):"

# Get Endpoint
Write-Host " Finding PSRemoting endpoint.. " -NoNewline
$VM = Get-AzureVM -Name $VMName -ServiceName $ServiceName
$EndpointPS = Get-AzureEndpoint -VM $VM -Name "Powershell"
$HostDNSName = (New-Object "System.Uri" $VM.DNSName).Authority

if ([string]::IsNullOrEmpty($HostDNSName)) {
	throw "DNS name not found for the service $($ServiceName)"
}

Write-Host " done"

# Create Credentials
$Sspw = ConvertTo-SecureString $Password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($Username, $Sspw)

Write-Host " Creating PSRemoting session.. " -NoNewline
# Create Session
$Session = New-PSSession -ComputerName $HostDNSName -Port $EndpointPS.Port  -Credential $Credentials -SessionOption (New-PSSessionOption -SkipCACheck) -UseSSL
Write-Host " done"


Write-Host " Running remote deployment commands.. "
Invoke-Command -Session $Session -ScriptBlock {
	# URL to installer executable
	$MediaUrl = "http://www.7-zip.org/a/7z1514-x64.exe"
	$DownloadFolder = "C:\Media\"
	$LocalFileName = "7-Zip-installer.exe"
	$DownloadFullpath = $DownloadFolder + $LocalFileName
	$InstallParameters = ' /S /D="C:\Program Files\7-Zip"'
	$InstallCommand = $DownloadFolder + $LocalFileName + $InstallParameters

	try {
		# Test if download folder exists
		if (!(Test-Path -Path $DownloadFolder)) {
			New-Item -ItemType Directory -Path $DownloadFolder | out-null
		}

		# Download Media
		Write-Host "  Downloading media.. " -NoNewline
		Invoke-WebRequest $MediaUrl -OutFile $DownloadFullpath
		Write-Host " done"

		Write-Host "  Running installer.. " -NoNewline
		Invoke-Expression $InstallCommand
		Write-Host " done"
	
	} catch {
		Write-Warning " 7-Zip deployment failed!"
		throw $_.Exception
	}
}

Write-Host " done"
Write-Host "7-zip succesfully installed on $($VMName)"

# clean
Remove-PSSession $Session
