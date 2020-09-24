# MS_Office365_licenses_tracking
Here are some PowerShell scripts which will give you an automation in terms of tracking MS/Office 365 licenses 

chk_licenses.ps1 is adapted to check only OFFICESUBSCRIPTION:OFFICE 365 PROPLUS
chk_licenses_all.ps1 will check all the subscriptions from the list - see README.md

.SYNOPSIS
chk_licenses - PowerShell script for checking the current state of used licenses in Office 365

.DESCRIPTION 
This script checks the current state of the used licenses in an Office 365 tenant and depending on the set threshold a warning mail will be sent to a given mail address. Also it can create a credential store from which user account credentials can be used for cennecting with the cloud tenant.

.PARAMETER nsc
Create a new cloud user account credentials in the same directory as the script

.PARAMETER gsc
Get an overview of all stored credentials

.PARAMETER cusr 
The cloud account userprincipalname (UPN) for tenant connect.

.PARAMETER mail 
The mail addresses of the receiving people.

.PARAMETER mrel 
The IP address of the mail relay server.

.PARAMETER [tres]
Optional: The license threshold, if not set 10 will be the limit.

.EXAMPLE
.\chk_licenses.ps1 nsc 
this will store the MS365 user account credentials in the same directory as the script

.EXAMPLE
.\chk_licenses.ps1 gsc

.EXAMPLE
.\chk_licenses.ps1 -cusr "CLOUDUSERACCOUNT@MAIL.COM" -mail "RECEIVERMAILADDRESS1@MAIL.COM", "RECEIVERMAILADDRESS2@MAIL.COM" -mrel "MAILRELAYSERVERIP" [-tres 10]
see also start.ps1 as an example


.NOTES
Written by: Julian Koehler and Leonid Levitchi

Based on https://docs.microsoft.com/en-us/microsoft-365/enterprise/view-licenses-and-services-with-microsoft-365-powershell?view=o365-worldwide

If you are not using Windows OS please consider this https://github.com/PowerShell/PowerShel in context of PowerShell installation.

