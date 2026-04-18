---
name: Installation tracking
description: .installed/ folder at project root tracks tool versions to skip redundant installs; also records errors for friendly retry messages
type: feature
---
`.installed/` at project root contains per-tool JSON files (e.g. `nodejs.json`, `git.json`).
Each records: name, version, method, installedAt, installedBy, lastError, errorAt.

Functions in `scripts/shared/installed.ps1` (auto-loaded by logging.ps1):
- `Test-AlreadyInstalled -Name <name> -CurrentVersion <ver>` -- returns $true if version matches and no error; if previous error exists, logs friendly retry message and returns $false
- `Save-InstalledRecord -Name <name> -Version <ver> -Method <method>` -- writes tracking file (clears lastError)
- `Save-InstalledError -Name <name> -ErrorMessage <msg>` -- records error so next run shows what went wrong
- `Get-InstalledRecord -Name <name>` -- reads tracking file

All install helpers should call `Save-InstalledError` in catch blocks and `Save-InstalledRecord` on success.
Delete a tracking JSON to force re-install of that tool.
