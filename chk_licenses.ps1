
param(
    [string]$cusr,
    [string[]]$mail,
    [string]$mrel,
    [int]$tres = 10
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ModulePath = Join-Path $ScriptDir "O365LicenseLib.psm1"

if (!(Test-Path $ModulePath)) {
    Write-Error "Module not found at $ModulePath"
    exit 1
}

Import-Module $ModulePath -Force

# Aliases for backward compatibility
Set-Alias -Name nsc -Value New-StoredCredential
Set-Alias -Name gsc -Value Get-StoredCredential

# Variables
$LogPath = Join-Path $ScriptDir "chk_licenses.log"
$PlanPath = Join-Path $ScriptDir "plan_names.txt"
$BodyPath = Join-Path $ScriptDir "body.txt"
$MailFrom = "noreply@example.com"
$KeyPath = $ScriptDir

Write-Log "#################################################" $LogPath

if ($cusr -eq "nsc") {
    Write-Log "Action: Creating new user credentials." $LogPath -ToConsole
    try {
        $msg = New-StoredCredential -KeyPath $KeyPath
        Write-Log $msg $LogPath -ToConsole
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)" $LogPath -ToConsole
    }
    exit
}

if ($cusr -eq "gsc") {
    Write-Log "Action: Listing user credentials." $LogPath -ToConsole
    Get-StoredCredential -KeyPath $KeyPath -List
    exit
}

# Validation
if (!($cusr)) {
    Write-Log "ERROR: No connect-user (cusr) provided." $LogPath -ToConsole
    exit 1
}

if (!($mail)) {
    Write-Log "ERROR: No recipient mail address (mail) provided." $LogPath -ToConsole
    exit 1
}

if (!($mrel)) {
    Write-Log "ERROR: No mail relay server (mrel) provided." $LogPath -ToConsole
    exit 1
}

if (!(Test-Path $PlanPath)) {
    Write-Log "ERROR: Plan name file not found at $PlanPath" $LogPath -ToConsole
    exit 1
}

# Clean up old body file
if (Test-Path $BodyPath) { Remove-Item $BodyPath -ErrorAction SilentlyContinue }

Write-Log "Connect-User: $cusr" $LogPath
Write-Log "Mail-user: $($mail -join ', ')" $LogPath
Write-Log "Mail-Relay-Server: $mrel" $LogPath
Write-Log "License threshold: $tres" $LogPath

# Connection
try {
    $Cred = Get-StoredCredential -KeyPath $KeyPath -UserName $cusr
    Connect-MsolService -Credential $Cred
    Write-Log "O365 connection successful." $LogPath
} catch {
    Write-Log "ERROR: Could not connect to O365! $($_.Exception.Message)" $LogPath -ToConsole
    exit 1
}

# Reporting
try {
    Write-Log "Checking for OFFICE 365 PROPLUS licenses..." $LogPath
    $Report = Get-LicenseReport -Filter "OFFICESUBSCRIPTION" -Threshold $tres -PlanFilePath $PlanPath

    if ($Report.Count -gt 0) {
        Write-Log "Critical subscriptions found: $($Report.Count)" $LogPath

        $BodyContent = "Following MS/Office365 Subscriptions have less than $tres licenses available:`r`n`r`n"
        $BodyContent += ($Report -join "`r`n")
        $BodyContent | Out-File $BodyPath -Encoding UTF8

        Write-Log "Sending mail report..." $LogPath
        Send-MailMessage -SmtpServer $mrel -To $mail -From $MailFrom -Subject "Office365 ProPlus: Available licenses report" -Body $BodyContent
        Write-Log "Mail sending successful." $LogPath
    } else {
        Write-Log "No critical subscriptions found." $LogPath
    }
} catch {
    Write-Log "ERROR during report generation: $($_.Exception.Message)" $LogPath -ToConsole
}

Write-Log "Script execution finished." $LogPath
