# CreateAzureVM.ps1
The purpose of this script is to create a VM in Azure.

## Requirements
To run this script you need to have an Azure subscription and the Azure Powershell module available. You can find instructions on how to obtain and configure the module at https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/
The script also requires you to login to Azure first. For example:

    Add-AzureAccount
 

## Syntax
### Simple parameter set
	CreateAzureVM.ps1 -VMName <string> -VMSize <string> -Password <string> -AdminUsername <string> -ServiceName <string>

#### Example

### More detailed parameter set for checking / creating Storage Account and ServiceGroup
	CreateAzureVM.ps1 -VMName <string> -VMSize <string> -Password <string> -AdminUsername <string> -ServiceName <string> -Location <string> -StorageName <string> [-ServiceLabel <string>] [-StorageLabel <string>]
	
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

