#Requires -Modules Azure

# URL to installer executable
$Media = "http://www.7-zip.org/a/7z1514-x64.exe"
$LocalFile = "7-Zip-installer.exe"
$DownloadFolder = "C:\Media\"
$InstallParameters = ' /S /D="C:\Program Files\7-Zip"'
$InstallCommand = $DownloadFolder + $LocalFile + $InstallParameters
Write-Host $InstallCommand

