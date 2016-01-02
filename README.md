# CreateAzureVM.ps1
The purpose of this script is to create a VM in Azure.

## Requirements
To run this script you need to have an Azure subscription and the Azure Powershell module available. You can find instructions on how to obtain and configure the module at https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/
The script also requires you to login to Azure first. For example:

    Add-AzureAccount
 

## Syntax
### Simple parameter set
	CreateAzureVM.ps1 -VMName <string> -VMSize <string> -Password <string> -AdminUsername <string> -ServiceName <string> -Location <string> [<CommonParameters>]

#### Example

### More detailed parameter set for checking / creating Storage Account and ServiceGroup
	CreateAzureVM.ps1 -VMName <string> -VMSize <string> -Password <string> -AdminUsername <string> -ServiceName <string> -Location <string> -StorageName <string> [<CommonParameters>]
	
#### Example
	CreateAzureVM.ps1 -VMName "NameOfYourVm" -VMSize Small -AdminUsername "NameOfAdminAccount" -Password "YourAdminPassword" -ServiceName "NameOfService" -Location "Central US" -StorageName "nameofyourstoragegroup"
## Output
The scripts prints out a status screen. An example:

	Creating Virtual Machine official1
	
  	StorageAccount Status              [ SUCCESS ]
  	AzureService Status                [ SUCCESS ]
  	Running New-AzureVM                [ SUCCESS ] 153s
  	Waiting for 'ReadyRole' status     [ WORKING ] 135s  Provisioningown
	 
### Statuses
There are four different statuses
* <font color='green'> SUCCESS</font> for succesfull operations
* <font color='red'>FAILURE</font> for failed operations. Usually this leads to the script aborting, except for when checking StorageAccount or AzureService existence
* <font color='yellow'>WORKING</font> is a blinking message and indicates that an operation is under way
* <font color='#66ffff'>WAITING</font> is a static message and indicates that the script is waiting for an operation that's status is not being monitored

Any of the first three statuses may be followed by a timer indicating the duration of the process

## Error and Warning handling
### Exceptions
The script handles exceptions. ErrorAction Stop is used frequently so Exceptions can be caught more easily. The script does not set $ErrorActionPreference globally

### Warnings
Currently the script does not print out any warnings raised by the cmdlets



# Deploy7Zip.p1

## Requirements
1. You must have Azure Powershell module installed.
2. You must be logged into the Azure powershell
3. You must obtain a certificate from the server. These instructions get the default self signed certificate.
 1. Open Powershell on the server and run command. This assumes that you haven't installed addition certificates
            (Get-ChildItem Cert:\LocalMachine\My)[0] | Export-Certificate -FilePath c:\cert.cer
 2. Copy the certificate to the machine you want to run the deployment script from
 3. Open certificate manager on the same machine and add manager for local machine instance (run -> mmc -> file -> add/remove snap-in -> certificates)
 4. Navigate to "Trusted Root Certification Authorities" and right click "Certificates". Choose "All Tasks" -> "Import"
 5. Browse to the cert.cer files and finish the dialog 
 
## Syntax
    Deploy7Zip.ps1 [-VMName] <string> [-ServiceName] <string> [-Username] <string> [-Password] <string> [<CommonParameters>] 

## Notes
This is a test script so it does not use a proper certificate. The script also skips CA check when connecting PS remote session