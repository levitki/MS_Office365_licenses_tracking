
Function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$LogPath,
        [switch]$ToConsole
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$Timestamp - $Message"
    try {
        $LogMessage | Out-File -FilePath $LogPath -Append -Encoding UTF8
    } catch {
        Write-Warning "Could not write to log file: $($_.Exception.Message)"
    }
    if ($ToConsole) {
        Write-Host $LogMessage
    }
}

Function New-StoredCredential {
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
    $CredPath = Join-Path $KeyPath "$($Credential.Username).cred"

    try {
        $Credential.Password | ConvertFrom-SecureString | Out-File $CredPath -Force
        return "User credential account $($Credential.Username) was successfully created at $CredPath."
    } catch {
        throw "Failed to save credential to $CredPath: $($_.Exception.Message)"
    }
}

Function Get-StoredCredential {
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyPath,
        [string]$UserName,
        [switch]$List
    )

    if ($List) {
        if (Test-Path $KeyPath) {
            Get-ChildItem -Path $KeyPath -Filter *.cred | ForEach-Object { Write-Host "Username: $($_.BaseName)" }
        } else {
            Write-Warning "Credential path $KeyPath does not exist."
        }
        return
    }

    if ($UserName) {
        $CredPath = Join-Path $KeyPath "$($UserName).cred"
        if (Test-Path $CredPath) {
            try {
                $PwdSecureString = Get-Content $CredPath | ConvertTo-SecureString
                return New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $PwdSecureString
            } catch {
                throw "Failed to load credential from $CredPath: $($_.Exception.Message)"
            }
        }
        else {
            throw "Unable to locate a credential for $($UserName) at $CredPath"
        }
    }
}

Function Get-LicenseReport {
    param(
        [string]$Filter,
        [int]$Threshold = 10,
        [Parameter(Mandatory=$true)]
        [string]$PlanFilePath
    )

    $PlanNames = @{}
    if (Test-Path $PlanFilePath) {
        Get-Content $PlanFilePath | ForEach-Object {
            if ($_ -match ":") {
                $parts = $_.Split(":", 2)
                $key = $parts[0].Trim()
                $value = $parts[1].Trim()
                if ($key) { $PlanNames[$key] = $value }
            }
        }
    }

    try {
        $AccountSkus = Get-MsolAccountSku
    } catch {
        throw "Failed to retrieve MsolAccountSku. Ensure you are connected to MsolService. Error: $($_.Exception.Message)"
    }

    if ($Filter) {
        $AccountSkus = $AccountSkus | Where-Object { $_.SkuPartNumber -match $Filter }
    }

    $ReportLines = @()
    foreach ($Sku in $AccountSkus) {
        $Available = $Sku.ActiveUnits - $Sku.ConsumedUnits
        # We only care about active subscriptions that are below threshold
        if ($Sku.ActiveUnits -gt 0 -and $Available -lt $Threshold) {
            $FriendlyName = if ($PlanNames.ContainsKey($Sku.SkuPartNumber)) { $PlanNames[$Sku.SkuPartNumber] } else { $Sku.SkuPartNumber }
            $ReportLines += "AboName: $FriendlyName, Total: $($Sku.ActiveUnits), Used: $($Sku.ConsumedUnits), Available: $Available"
        }
    }

    return $ReportLines
}

Export-ModuleMember -Function Write-Log, New-StoredCredential, Get-StoredCredential, Get-LicenseReport
