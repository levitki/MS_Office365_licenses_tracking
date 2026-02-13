<#
.SYNOPSIS
Unified Office 365 License Monitoring Script

.DESCRIPTION
Modern, unified script for monitoring Office 365 license usage with advanced features:
- JSON configuration file support
- Multiple API support (MSOnline and Microsoft Graph)
- HTML and text email reports
- Flexible filtering and thresholds
- Export capabilities (JSON, CSV, Text)
- Retry logic and robust error handling

.PARAMETER ConfigPath
Path to JSON configuration file. If not provided, will use command-line parameters.

.PARAMETER Action
Action to perform: Check (default), CreateCredential, ListCredentials, CreateConfig

.PARAMETER cusr
Cloud account username (UPN) for tenant connection.

.PARAMETER mail
Email addresses of recipients (array).

.PARAMETER mrel
SMTP relay server address.

.PARAMETER tres
Default license threshold. Default: 10

.PARAMETER Filter
Filter for specific license types (e.g., "OFFICESUBSCRIPTION" for ProPlus only)

.PARAMETER ExportPath
Optional path to export report data (JSON, CSV, or TXT based on extension)

.PARAMETER EmailFormat
Email format: Text or Html. Default: Text

.PARAMETER ApiType
API to use: MSOnline or Graph. Default: MSOnline

.PARAMETER WhatIf
Simulate execution without sending emails or making changes.

.EXAMPLE
.\chk_licenses_unified.ps1 -ConfigPath config.json

.EXAMPLE
.\chk_licenses_unified.ps1 -Action CreateCredential

.EXAMPLE
.\chk_licenses_unified.ps1 -Action CreateConfig -ConfigPath myconfig.json

.EXAMPLE
.\chk_licenses_unified.ps1 -cusr "admin@contoso.onmicrosoft.com" -mail "alerts@example.com" -mrel "smtp.example.com" -tres 10

.EXAMPLE
.\chk_licenses_unified.ps1 -ConfigPath config.json -Filter "OFFICESUBSCRIPTION" -EmailFormat Html

.EXAMPLE
.\chk_licenses_unified.ps1 -ConfigPath config.json -ExportPath "./reports/licenses.json" -WhatIf

.NOTES
Author: Leonid Levitchi
Version: 2.0
Last Updated: 2026-02-13

Based on original work by Julian Koehler
#>

param(
    [string]$ConfigPath,
    [ValidateSet("Check", "CreateCredential", "ListCredentials", "CreateConfig")]
    [string]$Action = "Check",
    [string]$cusr,
    [string[]]$mail,
    [string]$mrel,
    [int]$tres = 10,
    [string]$Filter,
    [string]$ExportPath,
    [ValidateSet("Text", "Html")]
    [string]$EmailFormat,
    [ValidateSet("MSOnline", "Graph")]
    [string]$ApiType,
    [switch]$WhatIf
)

#region Initialization

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ModulePath = Join-Path $ScriptDir "O365LicenseLib.psm1"

# Import module
if (!(Test-Path $ModulePath)) {
    Write-Error "Module not found at $ModulePath"
    exit 1
}

Import-Module $ModulePath -Force

# Default paths
$LogPath = Join-Path $ScriptDir "chk_licenses.log"
$PlanPath = Join-Path $ScriptDir "plan_names.txt"
$BodyPath = Join-Path $ScriptDir "body.txt"
$KeyPath = $ScriptDir

#endregion

#region Action Handlers

if ($Action -eq "CreateCredential") {
    Write-Host "`n=== Creating New Credential ===" -ForegroundColor Cyan
    try {
        $msg = New-StoredCredential -KeyPath $KeyPath
        Write-Host $msg -ForegroundColor Green
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    exit 0
}

if ($Action -eq "ListCredentials") {
    Write-Host "`n=== Stored Credentials ===" -ForegroundColor Cyan
    Get-StoredCredential -KeyPath $KeyPath -List
    exit 0
}

if ($Action -eq "CreateConfig") {
    Write-Host "`n=== Creating Configuration File ===" -ForegroundColor Cyan
    $outputPath = if ($ConfigPath) { $ConfigPath } else { Join-Path $ScriptDir "config.json" }
    try {
        New-DefaultConfig -OutputPath $outputPath
        Write-Host "Configuration file created successfully!" -ForegroundColor Green
        Write-Host "Edit the file and update with your settings." -ForegroundColor Yellow
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    exit 0
}

#endregion

#region Configuration Loading

$config = $null

if ($ConfigPath) {
    # Load from config file
    try {
        Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Cyan
        $config = Read-ConfigFile -ConfigPath $ConfigPath
        
        # Extract settings
        $cusr = $config.connection.userName
        $mail = $config.email.to
        $mrel = $config.email.smtp
        $tres = $config.thresholds.default
        $emailFrom = $config.email.from
        $emailSubject = $config.email.subject
        
        # Optional overrides
        if (!$Filter -and $config.filters -and $config.filters.Count -gt 0) {
            $Filter = $config.filters -join "|"
        }
        if (!$EmailFormat) { $EmailFormat = $config.email.format }
        if (!$ApiType) { $ApiType = $config.connection.apiType }
        
        $logLevel = $config.logging.level
        $logMaxSize = $config.logging.maxSizeKB
        $logMaxFiles = $config.logging.maxFiles
        $logToConsole = $config.logging.console
        
        $retryAttempts = $config.connection.retryAttempts
        $retryDelay = $config.connection.retryDelaySeconds
        
        $specificThresholds = $config.thresholds.specific
        
    } catch {
        Write-Host "ERROR loading config: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    # Use command-line parameters
    $emailFrom = "noreply@example.com"
    $emailSubject = "Office 365 License Alert"
    if (!$EmailFormat) { $EmailFormat = "Text" }
    if (!$ApiType) { $ApiType = "MSOnline" }
    $logLevel = "INFO"
    $logMaxSize = 1024
    $logMaxFiles = 5
    $logToConsole = $true
    $retryAttempts = 3
    $retryDelay = 5
    $specificThresholds = @{}
}

#endregion

#region Validation

Write-Log "########################################" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
Write-Log "Office 365 License Check - Unified Script v2.0" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles

if (!$cusr) {
    Write-Log "ERROR: No connect-user (cusr) provided." $LogPath -Level "ERROR" -ToConsole
    Write-Host "Use -ConfigPath or provide -cusr parameter" -ForegroundColor Yellow
    exit 1
}

if (!$mail) {
    Write-Log "ERROR: No recipient mail address provided." $LogPath -Level "ERROR" -ToConsole
    exit 1
}

if (!$mrel) {
    Write-Log "ERROR: No mail relay server provided." $LogPath -Level "ERROR" -ToConsole
    exit 1
}

if (!(Test-Path $PlanPath)) {
    Write-Log "WARNING: Plan name file not found at $PlanPath. Using SKU part numbers." $LogPath -Level "WARNING" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
}

#endregion

#region Logging Parameters

Write-Log "Configuration:" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
Write-Log "  Connect-User: $cusr" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
Write-Log "  Mail Recipients: $($mail -join ', ')" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
Write-Log "  Mail Relay: $mrel" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
Write-Log "  Default Threshold: $tres" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
Write-Log "  API Type: $ApiType" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
Write-Log "  Email Format: $EmailFormat" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
if ($Filter) {
    Write-Log "  Filter: $Filter" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
}
if ($WhatIf) {
    Write-Log "  Mode: SIMULATION (WhatIf)" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
}

#endregion

#region Connection

try {
    Write-Log "Retrieving credentials..." $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
    $Cred = Get-StoredCredential -KeyPath $KeyPath -UserName $cusr
    
    Write-Log "Connecting to Office 365 ($ApiType)..." $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
    $connectionResult = Connect-O365Service -Credential $Cred -ApiType $ApiType -RetryAttempts $retryAttempts -RetryDelaySeconds $retryDelay
    
    if ($connectionResult.Success) {
        Write-Log $connectionResult.Message $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
    } else {
        Write-Log $connectionResult.Message $LogPath -Level "ERROR" -ToConsole
        exit 1
    }
} catch {
    Write-Log "ERROR: Connection failed! $($_.Exception.Message)" $LogPath -Level "ERROR" -ToConsole
    exit 1
}

#endregion

#region License Report Generation

try {
    $filterMsg = if ($Filter) { "with filter '$Filter'" } else { "for all licenses" }
    Write-Log "Generating license report $filterMsg..." $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
    
    $Report = Get-LicenseReport -Filter $Filter -Threshold $tres -PlanFilePath $PlanPath -SpecificThresholds $specificThresholds -ApiType $ApiType
    
    if ($Report.Count -gt 0) {
        Write-Log "Found $($Report.Count) subscription(s) below threshold." $LogPath -Level "WARNING" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
        
        # Display report details
        foreach ($item in $Report) {
            $logMsg = "  - $($item.LicenseName): $($item.Available)/$($item.Total) available ($($item.PercentUsed)% used)"
            Write-Log $logMsg $LogPath -Level "WARNING" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
        }
        
        # Export if requested
        if ($ExportPath) {
            $extension = [System.IO.Path]::GetExtension($ExportPath).TrimStart('.')
            $format = switch ($extension) {
                "json" { "JSON" }
                "csv"  { "CSV" }
                default { "Text" }
            }
            
            Write-Log "Exporting report to: $ExportPath (Format: $format)" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
            
            if (!$WhatIf) {
                $exportDir = Split-Path -Parent $ExportPath
                if ($exportDir -and !(Test-Path $exportDir)) {
                    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
                }
                Export-LicenseReport -ReportData $Report -OutputPath $ExportPath -Format $format
            } else {
                Write-Log "  [WhatIf] Would export to: $ExportPath" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
            }
        }
        
        # Send email
        Write-Log "Preparing email report..." $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
        
        if (!$WhatIf) {
            try {
                Send-LicenseReport -ReportData $Report `
                                   -SmtpServer $mrel `
                                   -To $mail `
                                   -From $emailFrom `
                                   -Subject $emailSubject `
                                   -Threshold $tres `
                                   -Format $EmailFormat
                
                Write-Log "Email sent successfully to: $($mail -join ', ')" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
            } catch {
                Write-Log "ERROR sending email: $($_.Exception.Message)" $LogPath -Level "ERROR" -ToConsole
            }
        } else {
            Write-Log "  [WhatIf] Would send $EmailFormat email to: $($mail -join ', ')" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
        }
        
    } else {
        Write-Log "No subscriptions below threshold. All licenses are within acceptable limits." $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
    }
    
} catch {
    Write-Log "ERROR during report generation: $($_.Exception.Message)" $LogPath -Level "ERROR" -ToConsole
    exit 1
}

#endregion

#region Completion

Write-Log "Script execution completed successfully." $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles
Write-Log "########################################" $LogPath -Level "INFO" -ToConsole:$logToConsole -MaxSizeKB $logMaxSize -MaxFiles $logMaxFiles

if ($WhatIf) {
    Write-Host "`n[WhatIf Mode] No actual changes were made." -ForegroundColor Cyan
}

exit 0

#endregion
