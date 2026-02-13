# O365LicenseLib.psm1
# Enhanced Office 365 License Management Library
# Version: 2.0
# Last Updated: 2026-02-13

#region Configuration Management

Function Read-ConfigFile {
    <#
    .SYNOPSIS
    Reads and validates a JSON configuration file.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath
    )
    
    if (!(Test-Path $ConfigPath)) {
        throw "Configuration file not found at: $ConfigPath"
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return $config
    } catch {
        throw "Failed to parse configuration file: $($_.Exception.Message)"
    }
}

Function New-DefaultConfig {
    <#
    .SYNOPSIS
    Creates a default configuration file.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    $defaultConfig = @{
        connection = @{
            userName = "admin@contoso.onmicrosoft.com"
            apiType = "MSOnline"
            retryAttempts = 3
            retryDelaySeconds = 5
        }
        email = @{
            smtp = "smtp.example.com"
            from = "noreply@example.com"
            to = @("admin@example.com")
            format = "text"
            subject = "Office 365 License Alert"
        }
        logging = @{
            level = "INFO"
            maxSizeKB = 1024
            maxFiles = 5
            console = $true
        }
        thresholds = @{
            default = 10
            specific = @{
                OFFICESUBSCRIPTION = 5
                ENTERPRISEPREMIUM = 15
            }
        }
        filters = @()
        caching = @{
            enabled = $false
            expiryMinutes = 60
        }
    }
    
    $defaultConfig | ConvertTo-Json -Depth 10 | Out-File $OutputPath -Encoding UTF8
    Write-Host "Default configuration created at: $OutputPath" -ForegroundColor Green
}

#endregion

#region Logging Functions

Function Write-Log {
    <#
    .SYNOPSIS
    Advanced logging function with rotation and severity levels.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$LogPath,
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO",
        [switch]$ToConsole,
        [int]$MaxSizeKB = 1024,
        [int]$MaxFiles = 5
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$Timestamp [$Level] - $Message"
    
    # Log rotation
    if (Test-Path $LogPath) {
        $logFile = Get-Item $LogPath
        if ($logFile.Length -gt ($MaxSizeKB * 1024)) {
            # Rotate logs
            for ($i = $MaxFiles - 1; $i -gt 0; $i--) {
                $oldLog = "$LogPath.$i"
                $newLog = "$LogPath.$($i + 1)"
                if (Test-Path $oldLog) {
                    Move-Item $oldLog $newLog -Force
                }
            }
            Move-Item $LogPath "$LogPath.1" -Force
        }
    }
    
    # Write to log file
    try {
        $LogMessage | Out-File -FilePath $LogPath -Append -Encoding UTF8
    } catch {
        Write-Warning "Could not write to log file: $($_.Exception.Message)"
    }
    
    # Console output with colors
    if ($ToConsole) {
        $color = switch ($Level) {
            "DEBUG"   { "Gray" }
            "INFO"    { "White" }
            "WARNING" { "Yellow" }
            "ERROR"   { "Red" }
        }
        Write-Host $LogMessage -ForegroundColor $color
    }
}

#endregion

#region Credential Management

Function New-StoredCredential {
    <#
    .SYNOPSIS
    Creates and stores encrypted credentials using DPAPI.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyPath
    )
    
    if (!(Test-Path $KeyPath)) {
        try {
            New-Item -ItemType Directory -Path $KeyPath -ErrorAction Stop | Out-Null
        } catch {
            throw "Failed to create directory $KeyPath: $($_.Exception.Message)"
        }
    }

    $Credential = Get-Credential -Message "Enter the O365 user name (UPN) and password"
    if (!$Credential) {
        throw "No credentials provided."
    }
    
    $CredPath = Join-Path $KeyPath "$($Credential.Username).cred"

    try {
        # Use DPAPI for encryption (Windows only)
        $Credential.Password | ConvertFrom-SecureString | Out-File $CredPath -Force -Encoding UTF8
        return "User credential account $($Credential.Username) was successfully created at $CredPath."
    } catch {
        throw "Failed to save credential to $CredPath: $($_.Exception.Message)"
    }
}

Function Get-StoredCredential {
    <#
    .SYNOPSIS
    Retrieves stored credentials.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyPath,
        [string]$UserName,
        [switch]$List
    )

    if ($List) {
        if (Test-Path $KeyPath) {
            $creds = Get-ChildItem -Path $KeyPath -Filter *.cred
            if ($creds) {
                Write-Host "`nStored Credentials:" -ForegroundColor Cyan
                $creds | ForEach-Object { 
                    Write-Host "  - $($_.BaseName)" -ForegroundColor Green
                }
            } else {
                Write-Host "No stored credentials found." -ForegroundColor Yellow
            }
        } else {
            Write-Warning "Credential path $KeyPath does not exist."
        }
        return
    }

    if ($UserName) {
        $CredPath = Join-Path $KeyPath "$($UserName).cred"
        if (Test-Path $CredPath) {
            try {
                $PwdSecureString = Get-Content $CredPath -Raw | ConvertTo-SecureString
                return New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $PwdSecureString
            } catch {
                throw "Failed to load credential from $CredPath: $($_.Exception.Message)"
            }
        } else {
            throw "Unable to locate a credential for $UserName at $CredPath"
        }
    }
}

#endregion

#region Connection Functions

Function Connect-O365Service {
    <#
    .SYNOPSIS
    Connects to Office 365 with retry logic.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential,
        [ValidateSet("MSOnline", "Graph")]
        [string]$ApiType = "MSOnline",
        [int]$RetryAttempts = 3,
        [int]$RetryDelaySeconds = 5
    )
    
    $attempt = 0
    $connected = $false
    
    while ($attempt -lt $RetryAttempts -and !$connected) {
        $attempt++
        try {
            if ($ApiType -eq "MSOnline") {
                # Check if MSOnline module is available
                if (!(Get-Module -ListAvailable -Name MSOnline)) {
                    throw "MSOnline module is not installed. Install it with: Install-Module -Name MSOnline"
                }
                
                Import-Module MSOnline -ErrorAction Stop
                Connect-MsolService -Credential $Credential -ErrorAction Stop
                $connected = $true
                return @{ Success = $true; Message = "Connected to MSOnline successfully" }
            } elseif ($ApiType -eq "Graph") {
                # Check if Microsoft.Graph module is available
                if (!(Get-Module -ListAvailable -Name Microsoft.Graph)) {
                    throw "Microsoft.Graph module is not installed. Install it with: Install-Module -Name Microsoft.Graph"
                }
                
                Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
                Connect-MgGraph -Credential $Credential -ErrorAction Stop
                $connected = $true
                return @{ Success = $true; Message = "Connected to Microsoft Graph successfully" }
            }
        } catch {
            if ($attempt -lt $RetryAttempts) {
                Write-Warning "Connection attempt $attempt failed. Retrying in $RetryDelaySeconds seconds..."
                Start-Sleep -Seconds $RetryDelaySeconds
            } else {
                return @{ 
                    Success = $false
                    Message = "Failed to connect after $RetryAttempts attempts: $($_.Exception.Message)"
                }
            }
        }
    }
}

Function Test-O365Connection {
    <#
    .SYNOPSIS
    Tests if connection to O365 is active.
    #>
    param(
        [ValidateSet("MSOnline", "Graph")]
        [string]$ApiType = "MSOnline"
    )
    
    try {
        if ($ApiType -eq "MSOnline") {
            $null = Get-MsolDomain -ErrorAction Stop
            return $true
        } elseif ($ApiType -eq "Graph") {
            $null = Get-MgContext -ErrorAction Stop
            return $true
        }
    } catch {
        return $false
    }
}

#endregion

#region License Report Functions

Function Get-LicenseReport {
    <#
    .SYNOPSIS
    Generates license usage report with threshold warnings.
    #>
    param(
        [string]$Filter,
        [int]$Threshold = 10,
        [Parameter(Mandatory=$true)]
        [string]$PlanFilePath,
        [hashtable]$SpecificThresholds = @{},
        [ValidateSet("MSOnline", "Graph")]
        [string]$ApiType = "MSOnline"
    )

    # Load plan names
    $PlanNames = @{}
    if (Test-Path $PlanFilePath) {
        Get-Content $PlanFilePath | ForEach-Object {
            if ($_ -match "^\s*([^:]+):(.+)$") {
                $key = $Matches[1].Trim()
                $value = $Matches[2].Trim()
                if ($key) { $PlanNames[$key] = $value }
            }
        }
    }

    # Get license data
    try {
        if ($ApiType -eq "MSOnline") {
            $AccountSkus = Get-MsolAccountSku -ErrorAction Stop
        } elseif ($ApiType -eq "Graph") {
            $AccountSkus = Get-MgSubscribedSku -ErrorAction Stop
            # Convert Graph format to MSOnline format for compatibility
            $AccountSkus = $AccountSkus | Select-Object @{N='AccountSkuId';E={$_.SkuId}},
                                                         @{N='SkuPartNumber';E={$_.SkuPartNumber}},
                                                         @{N='ActiveUnits';E={$_.PrepaidUnits.Enabled}},
                                                         @{N='ConsumedUnits';E={$_.ConsumedUnits}}
        }
    } catch {
        throw "Failed to retrieve license data. Ensure you are connected to the service. Error: $($_.Exception.Message)"
    }

    # Apply filter
    if ($Filter) {
        $AccountSkus = $AccountSkus | Where-Object { $_.SkuPartNumber -match $Filter }
    }

    # Generate report
    $ReportLines = @()
    foreach ($Sku in $AccountSkus) {
        $Available = $Sku.ActiveUnits - $Sku.ConsumedUnits
        
        # Check specific threshold or use default
        $currentThreshold = if ($SpecificThresholds.ContainsKey($Sku.SkuPartNumber)) {
            $SpecificThresholds[$Sku.SkuPartNumber]
        } else {
            $Threshold
        }
        
        # Report only active subscriptions below threshold
        if ($Sku.ActiveUnits -gt 0 -and $Available -lt $currentThreshold) {
            $FriendlyName = if ($PlanNames.ContainsKey($Sku.SkuPartNumber)) { 
                $PlanNames[$Sku.SkuPartNumber] 
            } else { 
                $Sku.SkuPartNumber 
            }
            
            $percentUsed = [math]::Round(($Sku.ConsumedUnits / $Sku.ActiveUnits) * 100, 1)
            
            $ReportLines += [PSCustomObject]@{
                LicenseName = $FriendlyName
                SkuPartNumber = $Sku.SkuPartNumber
                Total = $Sku.ActiveUnits
                Used = $Sku.ConsumedUnits
                Available = $Available
                PercentUsed = $percentUsed
                Threshold = $currentThreshold
            }
        }
    }

    return $ReportLines
}

Function Export-LicenseReport {
    <#
    .SYNOPSIS
    Exports license report to various formats.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$ReportData,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        [ValidateSet("JSON", "CSV", "Text")]
        [string]$Format = "JSON"
    )
    
    try {
        switch ($Format) {
            "JSON" {
                $ReportData | ConvertTo-Json -Depth 10 | Out-File $OutputPath -Encoding UTF8
            }
            "CSV" {
                $ReportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            }
            "Text" {
                $ReportData | ForEach-Object {
                    "AboName: $($_.LicenseName), Total: $($_.Total), Used: $($_.Used), Available: $($_.Available), Usage: $($_.PercentUsed)%"
                } | Out-File $OutputPath -Encoding UTF8
            }
        }
        return "Report exported successfully to: $OutputPath"
    } catch {
        throw "Failed to export report: $($_.Exception.Message)"
    }
}

#endregion

#region Email Functions

Function New-HtmlEmailBody {
    <#
    .SYNOPSIS
    Generates professional HTML email body.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$ReportData,
        [int]$Threshold
    )
    
    $totalCritical = $ReportData.Count
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background-color: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; font-size: 24px; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; }
        .summary { padding: 20px 30px; background-color: #fff3cd; border-left: 4px solid #ffc107; margin: 20px 30px; }
        .summary h2 { margin: 0 0 10px 0; color: #856404; font-size: 18px; }
        .content { padding: 0 30px 30px 30px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th { background-color: #f8f9fa; padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6; font-weight: 600; }
        td { padding: 12px; border-bottom: 1px solid #dee2e6; }
        tr:hover { background-color: #f8f9fa; }
        .critical { color: #dc3545; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .footer { padding: 20px 30px; text-align: center; color: #6c757d; font-size: 12px; border-top: 1px solid #dee2e6; }
        .badge { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: bold; }
        .badge-critical { background-color: #dc3545; color: white; }
        .badge-warning { background-color: #ffc107; color: #000; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Office 365 License Alert</h1>
            <p>License threshold monitoring report</p>
        </div>
        
        <div class="summary">
            <h2>⚠️ Alert Summary</h2>
            <p><strong>$totalCritical</strong> subscription(s) have fewer than the configured threshold of available licenses.</p>
            <p style="margin-top: 8px; font-size: 14px;">Generated: $timestamp</p>
        </div>
        
        <div class="content">
            <h3>License Details</h3>
            <table>
                <thead>
                    <tr>
                        <th>License Name</th>
                        <th style="text-align: center;">Total</th>
                        <th style="text-align: center;">Used</th>
                        <th style="text-align: center;">Available</th>
                        <th style="text-align: center;">Usage %</th>
                        <th style="text-align: center;">Status</th>
                    </tr>
                </thead>
                <tbody>
"@

    foreach ($item in $ReportData) {
        $statusClass = if ($item.Available -eq 0) { "critical" } else { "warning" }
        $badgeClass = if ($item.Available -eq 0) { "badge-critical" } else { "badge-warning" }
        $statusText = if ($item.Available -eq 0) { "CRITICAL" } else { "LOW" }
        
        $html += @"
                    <tr>
                        <td><strong>$($item.LicenseName)</strong><br/><small style="color: #6c757d;">$($item.SkuPartNumber)</small></td>
                        <td style="text-align: center;">$($item.Total)</td>
                        <td style="text-align: center;">$($item.Used)</td>
                        <td style="text-align: center;" class="$statusClass">$($item.Available)</td>
                        <td style="text-align: center;">$($item.PercentUsed)%</td>
                        <td style="text-align: center;"><span class="badge $badgeClass">$statusText</span></td>
                    </tr>
"@
    }

    $html += @"
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p>This is an automated message from the Office 365 License Monitoring System.</p>
            <p>Please review and take appropriate action to avoid service interruptions.</p>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

Function Send-LicenseReport {
    <#
    .SYNOPSIS
    Sends license report via email.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$ReportData,
        [Parameter(Mandatory=$true)]
        [string]$SmtpServer,
        [Parameter(Mandatory=$true)]
        [string[]]$To,
        [Parameter(Mandatory=$true)]
        [string]$From,
        [Parameter(Mandatory=$true)]
        [string]$Subject,
        [int]$Threshold = 10,
        [ValidateSet("Text", "Html")]
        [string]$Format = "Text"
    )
    
    try {
        if ($Format -eq "Html") {
            $body = New-HtmlEmailBody -ReportData $ReportData -Threshold $Threshold
            Send-MailMessage -SmtpServer $SmtpServer -To $To -From $From -Subject $Subject -Body $body -BodyAsHtml
        } else {
            $body = "Following Office 365 Subscriptions have less than $Threshold licenses available:`r`n`r`n"
            $body += ($ReportData | ForEach-Object {
                "AboName: $($_.LicenseName), Total: $($_.Total), Used: $($_.Used), Available: $($_.Available), Usage: $($_.PercentUsed)%"
            }) -join "`r`n"
            Send-MailMessage -SmtpServer $SmtpServer -To $To -From $From -Subject $Subject -Body $body
        }
        return "Email sent successfully to: $($To -join ', ')"
    } catch {
        throw "Failed to send email: $($_.Exception.Message)"
    }
}

#endregion

# Export module members
Export-ModuleMember -Function `
    Read-ConfigFile, `
    New-DefaultConfig, `
    Write-Log, `
    New-StoredCredential, `
    Get-StoredCredential, `
    Connect-O365Service, `
    Test-O365Connection, `
    Get-LicenseReport, `
    Export-LicenseReport, `
    New-HtmlEmailBody, `
    Send-LicenseReport
