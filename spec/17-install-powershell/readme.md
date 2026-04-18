# Spec: Install PowerShell

## Overview

A PowerShell script that installs the **latest PowerShell** (`pwsh`) on Windows.
Tries **Winget** first (`Microsoft.PowerShell`), falls back to **Chocolatey**
(`powershell-core`) if Winget is unavailable or fails.

---

## File Structure

```
scripts/17-install-powershell/
├── config.json              # Winget ID, Choco fallback package
├── log-messages.json        # Display strings
├── run.ps1                  # Entry point
├── helpers/
│   └── powershell.ps1       # Install-PowerShellLatest function
└── logs/                    # Auto-created (gitignored)
```

## Usage

```powershell
.\run.ps1              # Install/verify latest PowerShell
.\run.ps1 -Help        # Show usage
```

## config.json Schema

| Key | Type | Description |
|-----|------|-------------|
| `enabled` | bool | Master enable/disable |
| `powershell.enabled` | bool | Whether to install/check pwsh |
| `powershell.wingetId` | string | Winget package ID (primary) |
| `powershell.fallbackChocoPackage` | string | Chocolatey package name (fallback) |
| `powershell.verifyCommand` | string | Command to verify (`pwsh`) |

## Execution Flow

1. If `-Help`: display usage and exit
2. Load shared + script helpers
3. Git pull (unless `$env:SCRIPTS_ROOT_RUN`)
4. Assert admin privileges
5. Check if `pwsh` is already installed
6. If not: try Winget install, refresh PATH
7. If still missing: fallback to Chocolatey, refresh PATH
8. Verify and save resolved version to `.resolved/`

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Winget first, Choco fallback | Winget provides official Microsoft package; Choco as safety net |
| Verifies `pwsh` not `powershell` | `pwsh` is the modern cross-platform PowerShell; `powershell` is Windows PowerShell 5.1 |

## Install Keywords

| Keyword |
|---------|
| `powershell` |
| `pwsh` |

```powershell
.\run.ps1 install powershell
```
