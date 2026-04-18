# Spec: PowerShell Context Menu

## Overview

A PowerShell utility that adds **"Open PowerShell Here"** entries to the Windows
Explorer right-click context menu -- both normal and elevated (Run as Admin).

---

## Problem

Windows does not always provide a convenient "Open PowerShell Here" option in
the context menu, especially for the modern `pwsh` (PowerShell 7+). Users need:

1. Right-click a **folder** -> "Open PowerShell Here"
2. Right-click the **background** of a folder -> "Open PowerShell Here"
3. Same as above but with **admin elevation** (UAC prompt)

## Solution

A structured PowerShell script that:

- Auto-detects the latest `pwsh.exe` (PowerShell 7+) with fallback to legacy `powershell.exe`
- Creates registry entries for both **normal** and **admin** modes
- Uses `HasLUAShield` registry value for proper UAC elevation prompts
- Reads all configuration from external JSON files

---

## File Structure

```
scripts/31-pwsh-context-menu/
  config.json                  # Paths, modes, registry keys (read-only at runtime)
  log-messages.json            # All display strings
  run.ps1                      # Main script entry point
  helpers/
    pwsh-menu.ps1              # Detection + registry helpers

spec/31-pwsh-context-menu/
  readme.md                    # This specification

.resolved/31-pwsh-context-menu/
  resolved.json                # Detected exe path, timestamp (auto-created)
```

## config.json Schema

| Key                          | Type     | Description                                    |
|------------------------------|----------|------------------------------------------------|
| `enabled`                    | bool     | Master enable/disable switch                   |
| `modes.normal`               | object   | Normal (non-elevated) context menu config      |
| `modes.admin`                | object   | Admin (elevated via UAC) context menu config   |
| `modes.*.contextMenuLabel`   | string   | Label shown in the right-click menu            |
| `modes.*.registryPaths.directory`  | string | Registry key for folder context menu     |
| `modes.*.registryPaths.background` | string | Registry key for folder background menu  |
| `modes.*.commandArgs.*`      | string   | Command template (`{exe}` replaced at runtime) |
| `modes.admin.runas`          | bool     | If true, sets HasLUAShield for UAC prompt      |
| `enabledModes`               | string[] | Which modes to process: `["normal", "admin"]`  |
| `pwshPaths.programFiles`     | string   | Scan path pattern for Program Files install    |
| `pwshPaths.winget`           | string   | WindowsApps path (winget installs)             |
| `pwshPaths.legacy`           | string   | Legacy powershell.exe fallback                 |
| `verifyCommand`              | string   | Command to check PATH (`pwsh`)                 |
| `versionFlag`                | string   | Flag to get version (`--version`)              |
| `fallbackToLegacy`           | bool     | Whether to fall back to powershell.exe          |

## Execution Flow

1. Load config and log messages
2. Display banner, run git pull
3. Assert Administrator privileges
4. **Detect PowerShell executable** (Resolve-PwshPath):
   a. Check `pwsh` on PATH
   b. Scan `C:\Program Files\PowerShell\{7,6,...}\pwsh.exe` (highest first)
   c. Check winget WindowsApps path
   d. Fallback to legacy `powershell.exe` (if enabled)
5. For each enabled mode (normal, admin):
   a. Register context menu for **directories**
   b. Register context menu for **folder backgrounds**
   c. For admin mode: set `HasLUAShield` for UAC elevation
   d. Verify all registry entries
6. Save resolved state to `.resolved/`
7. Display summary

## Admin Elevation (HasLUAShield)

The admin mode entry uses the `HasLUAShield` registry value, which tells
Windows Explorer to show the UAC shield icon and trigger an elevation prompt
when the menu item is clicked. The command itself runs normally -- Windows
handles the elevation via `ShellExecute` with the `runas` verb internally.

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+** (to run the script itself)
- **Administrator privileges**
- **pwsh installed** (script 17) or legacy powershell.exe as fallback

## Install Keywords

| Keyword |
|---------|
| `pwsh-menu` |
| `pwsh-context-menu` |
| `ps-context-menu` |

```powershell
.\run.ps1 install pwsh-menu
```
