# Spec: Install Chocolatey

## Overview

A PowerShell script that installs and/or updates **Chocolatey**
package manager on Windows. This is a prerequisite for scripts 03-09.

Winget was previously part of this script but has been extracted to
**script 14** (`14-install-winget`) as a standalone utility.

---

## File Structure

```
scripts/02-install-package-managers/
├── config.json              # Enable/disable, install URL
├── log-messages.json        # Display strings and banners
├── run.ps1                  # Thin orchestrator
├── helpers/
│   └── choco.ps1            # Install-Chocolatey function
└── logs/                    # Auto-created (gitignored)

.resolved/02-install-package-managers/
└── resolved.json            # Installed version + timestamp
```

## Usage

```powershell
.\run.ps1              # Install/update Chocolatey
.\run.ps1 -Help        # Show usage
```

## config.json Schema

| Key | Type | Description |
|-----|------|-------------|
| `enabled` | bool | Master enable/disable for the entire script |
| `chocolatey.enabled` | bool | Whether to install/check Chocolatey |
| `chocolatey.installUrl` | string | URL for Chocolatey install script |
| `chocolatey.upgradeOnRun` | bool | Upgrade Chocolatey itself on every run |

## Execution Flow

1. If `-Help`: display usage and exit
2. Load shared helpers (logging, choco-utils, resolved, help)
3. Load script helper (choco.ps1)
4. Git pull (unless `$env:SCRIPTS_ROOT_RUN`)
5. Assert admin privileges
6. Call `Install-Chocolatey` with config
7. Save resolved version to `.resolved/`
8. Display summary

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+**
- **Administrator privileges**
- **Internet access** (for downloads)

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Winget extracted to script 14 | Winget is optional and OS-bundled; keeps this script focused on Chocolatey |
| Assert-Choco from shared helper | Same logic reused by scripts 03-09 |
| Versions saved to .resolved/ | Other scripts can check prerequisite versions |
## Install Keywords

| Keyword |
|---------|
| `choco` |
| `chocolatey` |
| `package-managers` |
| `packagemanagers` |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `full-stack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `fullstack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `essentials` | 1, 2, 3, 7, 11 |

```powershell
.\run.ps1 install choco
.\run.ps1 install full-stack
```
