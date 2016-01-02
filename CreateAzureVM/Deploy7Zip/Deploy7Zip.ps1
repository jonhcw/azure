#Requires -Modules Azure

# URL to installer executable
$MediaUrl = "http://www.7-zip.org/a/7z1514-x64.exe"
$DownloadFolder = "C:\Media\"
$LocalFileName = "7-Zip-installer.exe"
$DownloadFullpath = $DownloadFolder + $LocalFileName
$InstallParameters = ' /S /D="C:\Program Files\7-Zip"'
$InstallCommand = $DownloadFolder + $LocalFile + $InstallParameters

Invoke-WebRequest $MediaUrl -OutFile $DownloadFullpath 

Invoke-Expression $InstallCommand

