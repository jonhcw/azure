#Requires -Modules Azure

# URL to installer executable
$MediaUrl = "http://www.7-zip.org/a/7z1514-x64.exe"
$DownloadFolder = "C:\Media\"
$LocalFileName = "7-Zip-installer.exe"
$DownloadFullpath = $DownloadFolder + $LocalFileName
$InstallParameters = ' /S /D="C:\Program Files\7-Zip"'
$InstallCommand = $DownloadFolder + $LocalFileName + $InstallParameters

# Test if download folder exists
if (!(Test-Path -Path $DownloadFolder)) {
	New-Item -ItemType Directory -Path $DownloadFolder
}


# Download Media
Write-Host ([string]::Format("  {0,-35}", "Downloading Media")) -NoNewline
Invoke-WebRequest $MediaUrl -OutFile $DownloadFullpath 


# Run installation command
Write-Host ([string]::Format("  {0,-35}", "Running installer")) -NoNewline
Invoke-Expression $InstallCommand

