# MS Office 365 License Tracking

Automated PowerShell scripts for monitoring Microsoft 365/Office 365 license usage with threshold alerts.

**Version 2.0** - Modernized with configuration file support, HTML emails, and Microsoft Graph API compatibility.

## Features

✅ **Automated License Monitoring** - Track license usage across all your Office 365 subscriptions  
✅ **Threshold Alerts** - Get notified when licenses are running low  
✅ **Multiple Report Formats** - HTML or plain text email reports  
✅ **Configuration File Support** - Easy setup with JSON config files  
✅ **Flexible Filtering** - Monitor specific license types or all licenses  
✅ **Export Capabilities** - Export data to JSON, CSV, or text files  
✅ **Retry Logic** - Robust error handling with automatic retries  
✅ **Modern API Support** - Works with MSOnline and Microsoft Graph API  
✅ **Log Rotation** - Automatic log file management

## Quick Start

### Prerequisites

1. **PowerShell 5.1 or later** (PowerShell 7+ recommended)

2. **Internet Access** with TLS 1.2:
   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   ```

3. **MSOnline Module** (or Microsoft.Graph for Graph API):
   ```powershell
   Install-Module -Name MSOnline
   # OR for Microsoft Graph API (recommended for new deployments):
   Install-Module -Name Microsoft.Graph
   ```

### Installation

1. Clone or download this repository
2. Navigate to the script directory
3. Create a configuration file:
   ```powershell
   .\chk_licenses_unified.ps1 -Action CreateConfig
   ```

4. Edit `config.json` with your settings

5. Store your credentials:
   ```powershell
   .\chk_licenses_unified.ps1 -Action CreateCredential
   ```

### Basic Usage

**Using configuration file (recommended):**
```powershell
.\chk_licenses_unified.ps1 -ConfigPath config.json
```

**Using command-line parameters:**
```powershell
.\chk_licenses_unified.ps1 -cusr "admin@contoso.onmicrosoft.com" -mail "alerts@example.com" -mrel "smtp.example.com" -tres 10
```

**Check specific licenses only:**
```powershell
.\chk_licenses_unified.ps1 -ConfigPath config.json -Filter "OFFICESUBSCRIPTION"
```

**HTML email report:**
```powershell
.\chk_licenses_unified.ps1 -ConfigPath config.json -EmailFormat Html
```

**Export to file:**
```powershell
.\chk_licenses_unified.ps1 -ConfigPath config.json -ExportPath "./reports/licenses.json"
```

**Test run (WhatIf mode):**
```powershell
.\chk_licenses_unified.ps1 -ConfigPath config.json -WhatIf
```

## Configuration File

The `config.json` file allows you to configure all settings in one place:

```json
{
  "connection": {
    "userName": "admin@contoso.onmicrosoft.com",
    "apiType": "MSOnline",
    "retryAttempts": 3,
    "retryDelaySeconds": 5
  },
  "email": {
    "smtp": "smtp.example.com",
    "from": "noreply@example.com",
    "to": ["admin@example.com", "alerts@example.com"],
    "format": "html",
    "subject": "Office 365 License Alert"
  },
  "logging": {
    "level": "INFO",
    "maxSizeKB": 1024,
    "maxFiles": 5,
    "console": true
  },
  "thresholds": {
    "default": 10,
    "specific": {
      "OFFICESUBSCRIPTION": 5,
      "ENTERPRISEPREMIUM": 15
    }
  },
  "filters": [],
  "caching": {
    "enabled": false,
    "expiryMinutes": 60
  }
}
```

## Scripts Overview

### Main Scripts

| Script | Description | Status |
|--------|-------------|--------|
| **chk_licenses_unified.ps1** | Modern unified script with all features | ✅ **Recommended** |
| chk_licenses.ps1 | Legacy script for Office 365 ProPlus only | ⚠️ Deprecated |
| chk_licenses_all.ps1 | Legacy script for all licenses | ⚠️ Deprecated |

### Supporting Files

- **O365LicenseLib.psm1** - Core library module with all functions
- **config-sample.json** - Sample configuration file template
- **plan_names.txt** - License SKU to friendly name mappings
- **start.ps1** - Example starter script

## Migration from Legacy Scripts

If you're using the old `chk_licenses.ps1` or `chk_licenses_all.ps1`:

1. **Create a config file:**
   ```powershell
   .\chk_licenses_unified.ps1 -Action CreateConfig -ConfigPath myconfig.json
   ```

2. **Edit the config file** with your existing parameters:
   - `cusr` → `connection.userName`
   - `mrel` → `email.smtp`
   - `mail` → `email.to`
   - `tres` → `thresholds.default`

3. **Your existing credentials will work** - no need to recreate them

4. **Run the new script:**
   ```powershell
   .\chk_licenses_unified.ps1 -ConfigPath myconfig.json
   ```

## Scheduling

To run automatically on a schedule:

**Windows Task Scheduler:**
```powershell
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File "C:\scripts\chk_licenses_unified.ps1" -ConfigPath "C:\scripts\config.json"'
$trigger = New-ScheduledTaskTrigger -Daily -At 8am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Office365 License Check" -Description "Daily Office 365 license monitoring"
```

**Linux/macOS Cron:**
```bash
# Run daily at 8 AM
0 8 * * * /usr/local/bin/pwsh /path/to/chk_licenses_unified.ps1 -ConfigPath /path/to/config.json
```

## Advanced Examples

### Multiple Tenants
```powershell
# Create separate config files for each tenant
.\chk_licenses_unified.ps1 -ConfigPath tenant1.json
.\chk_licenses_unified.ps1 -ConfigPath tenant2.json
```

### Custom Thresholds per License
Edit `config.json`:
```json
{
  "thresholds": {
    "default": 10,
    "specific": {
      "OFFICESUBSCRIPTION": 5,      // Alert when < 5 Office ProPlus licenses
      "ENTERPRISEPREMIUM": 20,       // Alert when < 20 E5 licenses  
      "POWER_BI_PRO": 3              // Alert when < 3 Power BI Pro licenses
    }
  }
}
```

### Export and Analyze Over Time
```powershell
# Daily export with timestamp
$date = Get-Date -Format "yyyy-MM-dd"
.\chk_licenses_unified.ps1 -ConfigPath config.json -ExportPath "./reports/licenses-$date.json"
```

## Troubleshooting

### Common Issues

**"Module not found" error:**
```powershell
Install-Module -Name MSOnline -Force
```

**"Unable to connect to Office 365":**
- Verify credentials are correct
- Check internet connectivity
- Ensure TLS 1.2 is enabled
- Try re-creating credentials with `-Action CreateCredential`

**"Failed to send email":**
- Verify SMTP server address and port
- Check firewall settings
- Some SMTP servers require authentication (use relay that allows unauthenticated local sends)

**Encoding issues:**
- All files are UTF-8 encoded
- If you see garbled characters, convert files to UTF-8

### Enable Debug Logging

Edit `config.json`:
```json
{
  "logging": {
    "level": "DEBUG",
    "console": true
  }
}
```

### Test Connection
```powershell
# Manual connection test
Import-Module MSOnline
$cred = Get-Credential
Connect-MsolService -Credential $cred
Get-MsolAccountSku
```

## API Migration

**MSOnline module is being deprecated by Microsoft.** While still supported in these scripts, consider migrating to Microsoft Graph API:

1. Install the Graph module:
   ```powershell
   Install-Module -Name Microsoft.Graph -Scope CurrentUser
   ```

2. Update `config.json`:
   ```json
   {
     "connection": {
       "apiType": "Graph"
     }
   }
   ```

3. Register an app in Azure AD and configure appropriate permissions (see [MIGRATION.md](MIGRATION.md) when available)

## License SKU Reference

See `plan_names.txt` for all supported license SKUs, or check Microsoft's official documentation:
- [Azure AD Service Plan Reference](https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/licensing-service-plan-reference)

Common SKU Part Numbers:
- `OFFICESUBSCRIPTION` - Office 365 ProPlus
- `ENTERPRISEPREMIUM` - Office 365 Enterprise E5
- `ENTERPRISEPACK` - Office 365 Enterprise E3
- `SPE_E3` - Microsoft 365 E3
- `SPE_E5` - Microsoft 365 E5

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## Credits

- **Original Author:** Julian Koehler
- **Enhanced by:** Leonid Levitchi
- **Contributors:** Bernd Bürkle and community

## Support

For questions or issues:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review closed issues in the repository
3. Open a new issue with detailed information

## Notes

**Continuous Cost Control:** Use this automation to maintain visibility into your license usage and optimize costs by adjusting subscriptions as needed.

**Pro Tip:** Many Microsoft resellers offer self-service portals where you can adjust license counts directly through a web interface.

---

**Made with ❤️ for Office 365 administrators everywhere**
