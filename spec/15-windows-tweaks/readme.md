# Spec: Windows Tweaks

## Overview

A PowerShell script that launches the **Chris Titus Windows Utility**
(`christitus.com/win`) for system tweaks, debloating, and Windows
configuration. This is a standalone utility kept outside the "Install All
Dev Tools" orchestrator (script 12).

---

## File Structure

```
scripts/15-windows-tweaks/
├── config.json              # URL, confirmation toggle
├── log-messages.json        # Display strings
├── run.ps1                  # Thin orchestrator
├── helpers/
│   └── tweaks.ps1           # Invoke-WindowsTweaks function
└── logs/                    # Auto-created (gitignored)

.resolved/15-windows-tweaks/
└── resolved.json            # Execution timestamp
```

## Usage

```powershell
.\run.ps1              # Launch the utility (with confirmation prompt)
.\run.ps1 -Help        # Show usage
```

Or via root dispatcher:

```powershell
.\run.ps1 -I 15        # Run via root dispatcher
.\run.ps1 -t           # Shortcut for -I 15
```

## config.json Schema

| Key | Type | Description |
|-----|------|-------------|
| `enabled` | bool | Master enable/disable for the entire script |
| `tweaks.url` | string | URL for the Chris Titus utility script |
| `tweaks.confirmBeforeRun` | bool | Prompt user for confirmation before downloading and running |

## Execution Flow

1. If `-Help`: display usage and exit
2. Load shared helpers (logging, resolved, help)
3. Load script helper (tweaks.ps1)
4. Git pull (unless `$env:SCRIPTS_ROOT_RUN`)
5. Assert admin privileges
6. If `confirmBeforeRun`: prompt Y/N
7. Download script via `Invoke-RestMethod`
8. Execute via `Invoke-Expression`
9. Save resolved timestamp to `.resolved/`

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Outside orchestrator (script 12) | System tweaks are not dev tool installs; user preference |
| Confirmation prompt by default | Running remote scripts should require explicit consent |
| Configurable URL | Allows pointing to forks or specific versions |

## Install Keywords

| Keyword |
|---------|
| `tweaks` |
| `windows-tweaks` |
| `windowstweaks` |

```powershell
.\run.ps1 install tweaks
```
