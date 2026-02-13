# Changelog

All notable changes to the MS Office 365 License Tracking project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-02-13

### Added
- **New unified script** (`chk_licenses_unified.ps1`) consolidating all functionality
- **JSON configuration file support** for easier management
- **HTML email templates** with professional formatting and color-coded alerts
- **Microsoft Graph API support** (in addition to MSOnline)
- **Advanced logging system** with rotation, severity levels, and colored console output
- **Retry logic** for connection failures with configurable attempts and delays
- **Export capabilities** to JSON, CSV, and text formats
- **WhatIf mode** for testing without sending emails
- **Specific thresholds** per license type
- **Flexible filtering** for monitoring specific licenses
- **Configuration file generator** (`-Action CreateConfig`)
- **Improved credential management** with better error messages
- **Sample configuration file** (`config-sample.json`)
- **Comprehensive README** with examples and troubleshooting
- **Modern license SKUs** added to `plan_names.txt` (Microsoft 365 E3, E5, F1, F3, Teams Phone, etc.)

### Changed
- **Enhanced `O365LicenseLib.psm1`** with complete rewrite including:
  - Better error handling and validation
  - Modular function design
  - Configuration file reader
  - HTML email body generator
  - Export functions for multiple formats
- **Updated `README.md`** with modern documentation, examples, and migration guide
- **Fixed `start.ps1`** encoding issues (converted from UTF-16 to UTF-8)
- **Improved `plan_names.txt`** with consistent line endings (LF) and sorted entries
- **Legacy scripts** now show deprecation warnings but remain functional

### Deprecated
- `chk_licenses.ps1` - Use `chk_licenses_unified.ps1` instead
- `chk_licenses_all.ps1` - Use `chk_licenses_unified.ps1` instead
- MSOnline API (Microsoft is deprecating it in favor of Microsoft Graph)

### Fixed
- Line ending inconsistencies in `plan_names.txt` (CRLF → LF)
- Encoding issues in `start.ps1` (UTF-16 → UTF-8)
- Missing error handling in credential operations
- Log file growth without rotation
- Hardcoded values scattered throughout code

### Security
- Improved credential storage with proper DPAPI encryption documentation
- Better error messages that don't expose sensitive information

## [1.0.0] - Prior versions

### Features
- Basic license monitoring with MSOnline module
- Email alerts via SMTP
- Credential storage
- Two separate scripts for specific vs. all licenses
- Simple text-based logging

---

## Migration Guide from 1.x to 2.0

### Breaking Changes
**None** - Version 2.0 is fully backward compatible. Old scripts will continue to work with deprecation warnings.

### Recommended Migration Steps

1. **Create a configuration file:**
   ```powershell
   .\chk_licenses_unified.ps1 -Action CreateConfig -ConfigPath config.json
   ```

2. **Edit `config.json`** with your settings from the old command-line parameters

3. **Test the new script:**
   ```powershell
   .\chk_licenses_unified.ps1 -ConfigPath config.json -WhatIf
   ```

4. **Update scheduled tasks** to use the new script

5. **Optional: Enable HTML emails** by setting `"format": "html"` in config.json

6. **Optional: Plan for Graph API migration** (MSOnline is being deprecated)

### What You Get
- Easier configuration management (one JSON file vs. long command lines)
- Beautiful HTML email reports
- Better error handling and logging
- Export capabilities for analysis
- Future-proof with Graph API support
