

param(
	[string]$cusr,
	[string[]]$mail,
	[string]$mrel,
	[int]$tres
)

$KeyPath = split-path -parent $MyInvocation.MyCommand.Definition

Function New-StoredCredential 
{
    if (!(Test-Path Variable:\KeyPath)) {
        Write-Warning "The `$KeyPath variable has not been set. Consider adding `$KeyPath to your PowerShell profile to avoid this prompt."
        $path = Read-Host -Prompt "Enter a path for stored credentials"
        Set-Variable -Name KeyPath -Scope Global -Value $path

        if (!(Test-Path $KeyPath)) {
        
            try {
                New-Item -ItemType Directory -Path $KeyPath -ErrorAction STOP | Out-Null
            }
            catch {
                throw $_.Exception.Message
            }           
        }
    }

    $Credential = Get-Credential -Message "Enter a user name and password"

    $Credential.Password | ConvertFrom-SecureString | Out-File "$($KeyPath)\$($Credential.Username).cred" -Force
	
	echo "User credential account $($Credential.Username) was successfully created." >>$log
}
Set-Alias -Name nsc -Value New-StoredCredential

Function Get-StoredCredential 
{
    param(
        [Parameter(Mandatory=$false, ParameterSetName="Get")]
        [string]$UserName,
        [Parameter(Mandatory=$false, ParameterSetName="List")]
        [switch]$List
        )

    if (!(Test-Path Variable:\KeyPath)) {
        Write-Warning "The `$KeyPath variable has not been set. Consider adding `$KeyPath to your PowerShell profile to avoid this prompt."
        $path = Read-Host -Prompt "Enter a path for stored credentials"
        Set-Variable -Name KeyPath -Scope Global -Value $path
    }


    if ($List) {

        try {
        $CredentialList = @(Get-ChildItem -Path $keypath -Filter *.cred -ErrorAction STOP)

        foreach ($Cred in $CredentialList) {
            Write-Host "Username: $($Cred.BaseName)"
            }
        }
        catch {
            Write-Warning $_.Exception.Message
        }

    }

    if ($UserName) {
        if (Test-Path "$($KeyPath)\$($Username).cred") {
        
            $PwdSecureString = Get-Content "$($KeyPath)\$($Username).cred" | ConvertTo-SecureString
            
            $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $PwdSecureString
        }
        else {
            throw "Unable to locate a credential for $($Username)" >>$log
			date >>$log
			exit
        }

        return $Credential
    }
}
Set-Alias -Name gsc -Value Get-StoredCredential

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#Script Version
$sScriptVersion = "1.0.0"

###	variablen
$body = "$KeyPath\body.txt"
$plan = "$KeyPath\plan_names.txt"
$log = "$KeyPath\chk_licenses.log"
$mrep = "noreply@example.com"
$chk = 0

echo "" >>$log
echo "#################################################" >>$log
date >>$log

if (!($cusr))
{
	echo "No connect-user were given, exiting!" >>$log
	date >>$log
	exit
}
elseif ( $cusr -eq "nsc" )
{
	echo "Creating new user credentials." >>$log
	nsc
	
	date >>$log
	exit
}
elseif ( $cusr -eq "gsc" )
{
	echo "Listing new user credentials." >>$log
	gsc -List
	
	date >>$log
	exit
}

if (!($mail))
{
	echo "No mail-user were given, exiting!" >>$log
	date >>$log
	exit
}

if (!($mrel))
{
	echo "No mail-relay-server were given, exiting!" >>$log
	date >>$log
	exit
}

if (!($tres))
{
	echo "No threshold were given, setting it to 10!" >>$log
	$tres = 10
}

if (!(Test-Path $plan) )
{
	echo "O365 naming list is not in the same directory as the script, exiting!" >>$log
	exit
}

if ( Test-Path $body )
{
	del $body
}

echo "Connect-User: $cusr"  >>$log
echo "Mail-user: $mail"  >>$log
echo "Mail-Relay-Server: $mrel"  >>$log
echo "License threshold: $tres"  >>$log

echo "Following Azure/MS/Office365 Subscriptions have less than $tres licenses available:" >> $body
echo "" >> $body

Connect-MsolService -Credential (Get-StoredCredential -UserName $cusr)
if ( $? )
{
	echo "O365 connect successfull." >>$log
}
else
{
	echo "Could not connect to O365!" >>$log
	date >>$log
	exit
}

$erg = Get-MsolAccountSku
foreach ($er in $erg) { if ( $er.ActiveUnits -gt 0 ) { if (($er.ActiveUnits-$er.ConsumedUnits) -lt $tres) { $chk = 1; foreach ( $lin in `gc $plan` ) { if ($lin -match $er.SkuPartNumber) { $nam = $lin.split(":")[1] ; 
echo "AboName: $nam, Total: $($er.ActiveUnits), Used: $($er.ConsumedUnits), Available $(($er.ActiveUnits-$er.ConsumedUnits)) " >> $body ; echo "" >> $body } } } } }

if ( $chk -eq 1 )
{
	echo "Critical Abos found!" >>$log
	echo "" >>$log
	gc $body | Out-String >>$log
	
	Send-MailMessage -SmtpServer $mrel -To $mail -From $mrep -Subject "Office365/Azure: Available licenses report" -body (gc $body | Out-String)
	if ( $? )
	{
		echo "Mail sending successfull." >>$log
	}
	else
	{
		echo "Could not send Mail to $mails!" >>$log
	}
}
else
{
	echo "No critical Abos found!" >>$log
}

date >>$log

exit