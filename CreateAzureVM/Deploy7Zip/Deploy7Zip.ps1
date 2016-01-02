#Requires -Modules Azure

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
	Write-Host "Downloading media.. " -NoNewline
	Invoke-WebRequest $MediaUrl -OutFile $DownloadFullpath -ErrorAction Stop
	Write-Host " File downloaded"

	Write-Host "Running installer.. " -NoNewline
	Invoke-Expression $InstallCommand -ErrorAction Stop
	Write-Host " 7-Zip installed"
	
} catch {
	Write-Host "7-Zip deployment failed!"
	throw $_.Exception
}

