# Example starter script for Office 365 License Monitoring
# Updated for chk_licenses_unified.ps1

# Option 1: Using configuration file (RECOMMENDED)
# First, create a config file if you haven't already:
# .\chk_licenses_unified.ps1 -Action CreateConfig

# Then run with the config file:
.\chk_licenses_unified.ps1 -ConfigPath "config.json"

# Option 2: Using command-line parameters
# .\chk_licenses_unified.ps1 -cusr "read_serviceaccount@yourdomain.onmicrosoft.com" -mail "contact@example.com" -mrel "smtp.hostname.com" -tres 10

# Option 3: With HTML email format
# .\chk_licenses_unified.ps1 -ConfigPath "config.json" -EmailFormat Html

# Option 4: Filter for specific licenses only (e.g., Office 365 ProPlus)
# .\chk_licenses_unified.ps1 -ConfigPath "config.json" -Filter "OFFICESUBSCRIPTION"

# Option 5: Export to JSON file
# .\chk_licenses_unified.ps1 -ConfigPath "config.json" -ExportPath "./reports/licenses.json"

# Option 6: Test run (WhatIf mode - no emails sent)
# .\chk_licenses_unified.ps1 -ConfigPath "config.json" -WhatIf

exit
