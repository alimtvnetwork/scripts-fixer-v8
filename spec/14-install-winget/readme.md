# Spec: Install Winget

## Overview

A standalone PowerShell script that installs and verifies the **Winget**
(App Installer) package manager on Windows. Extracted from the former
script 02 (Package Managers) so it can be run independently and is kept
outside the "Install All Dev Tools" orchestrator (script 12).

---

## File Structure

```
scripts/14-install-winget/
├── config.json              # Enable/disable, install URL
├── log-messages.json        # Display strings and banners
├── run.ps1                  # Thin orchestrator
├── helpers/
│   └── winget.ps1           # Install-Winget function
└── logs/                    # Auto-created (gitignored)

.resolved/14-install-winget/
└── resolved.json            # Installed version + timestamp
```

## Usage

```powershell
.\run.ps1              # Install/verify Winget
.\run.ps1 -Help        # Show usage
```

Or via root dispatcher:

```powershell
.\run.ps1 -I 14        # Run via root dispatcher
```

## config.json Schema

| Key | Type | Description |
|-----|------|-------------|
| `enabled` | bool | Master enable/disable for the entire script |
| `winget.enabled` | bool | Whether to install/check Winget |
| `winget.installIfMissing` | bool | Install Winget if not found |
| `winget.msStoreUrl` | string | Download URL for App Installer package |

## Execution Flow

1. If `-Help`: display usage and exit
2. Load shared helpers (logging, resolved, help)
3. Load script helper (winget.ps1)
4. Git pull (unless `$env:SCRIPTS_ROOT_RUN`)
5. Assert admin privileges
6. Call `Install-Winget` with config
7. Save resolved version to `.resolved/`
8. Display summary

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Separate from script 02 | Winget is optional and OS-bundled; Chocolatey is the primary package manager |
| Outside orchestrator (script 12) | User preference -- not part of the standard dev tools install flow |
| Same helper pattern | Consistent with all other scripts in the project |

## Install Keywords

| Keyword |
|---------|
| `winget` |

```powershell
.\run.ps1 install winget
```
