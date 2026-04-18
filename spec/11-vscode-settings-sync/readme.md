# Spec: VS Code Profile Importer

## Overview

A PowerShell utility that imports a full VS Code profile — **settings.json**,
**keybindings.json**, and **extensions** — for both **Stable** and **Insiders** editions.

---

## Problem

Setting up VS Code on a new machine or after a reinstall requires:

1. Manually copying `settings.json` and `keybindings.json`
2. Individually installing each extension
3. Exporting/importing profiles through VS Code's UI

This is tedious and error-prone, especially when maintaining the same config
across multiple machines.

## Solution

A structured PowerShell script that:

- Accepts a `.code-profile` export file **or** individual JSON files
- Parses the profile to extract settings, keybindings, and extension list
- Backs up existing files before overwriting
- Copies `settings.json` and `keybindings.json` into the correct VS Code user settings path
- Installs all enabled extensions via CLI (`code --install-extension`)
- Supports both **VS Code Stable** and **VS Code Insiders**
- Provides colorful, structured terminal output with status badges

---

## File Structure

```
run.ps1                                # Root dispatcher (git pull + delegate)
scripts/
├── shared/
│   ├── git-pull.ps1                   # Shared git-pull helper (dot-sourced)
│   ├── logging.ps1                    # Write-Log, Write-Banner, Initialize-Logging, Import-JsonConfig
│   ├── json-utils.ps1                 # Backup-File, Merge-JsonDeep, ConvertTo-OrderedHashtable
│   ├── resolved.ps1                   # Save-ResolvedData, Get-ResolvedDir
│   └── cleanup.ps1                    # Clear-ResolvedData
└── 02-vscode-settings-sync/
    ├── config.json                    # Paths & edition settings (never mutated at runtime)
    ├── log-messages.json              # All display strings & banners
    ├── settings.json                  # Extracted/provided VS Code settings
    ├── keybindings.json               # Extracted/provided keybindings
    ├── extensions.json                # Extension IDs (enabled & disabled)
    ├── *.code-profile                 # (Optional) VS Code profile export
    ├── run.ps1                        # Thin orchestrator (loads helpers, runs flow)
    ├── helpers/
    │   └── sync.ps1                   # Script-specific functions (resolve, apply, install)
    └── logs/                          # Auto-created runtime log folder (gitignored)
        └── run-<timestamp>.log        # Timestamped execution log

.resolved/                             # Runtime-resolved data (gitignored)
└── 02-vscode-settings-sync/
    └── resolved.json                  # Resolved settings dirs, CLI commands, timestamps

spec/
├── shared/
│   └── readme.md                      # Shared helpers specification
└── 02-vscode-settings-sync/
    └── readme.md                      # This specification
```

## Input Priority

The script uses this priority for source data:

1. **`.code-profile` file** — If present in the script folder, the profile is
   parsed automatically to extract settings, keybindings, and extensions.
2. **Individual JSON files** — Falls back to `settings.json`, `keybindings.json`,
   and `extensions.json` if no profile file is found (or parsing fails).

## config.json Schema

| Key                                  | Type     | Description                                         |
|--------------------------------------|----------|-----------------------------------------------------|
| `editions.stable.settingsPath`       | string   | Path to Stable VS Code user settings dir            |
| `editions.stable.cliCommand`         | string   | CLI command for Stable (`code`)                     |
| `editions.insiders.settingsPath`     | string   | Path to Insiders VS Code user settings dir          |
| `editions.insiders.cliCommand`       | string   | CLI command for Insiders (`code-insiders`)          |
| `enabledEditions`                    | string[] | Which editions to target (`["stable","insiders"]`)  |
| `backupSuffix`                       | string   | Suffix for backup files (e.g. `.backup`)            |

## extensions.json Schema

```json
{
  "extensions": ["id1", "id2"],
  "disabled": ["id3", "id4"]
}
```

Only `extensions` (enabled) are installed. The `disabled` list is kept for reference.

## Script Architecture

The script follows the same pattern as script 01: a **thin `run.ps1` orchestrator**
that dot-sources shared helpers and a script-specific `helpers/sync.ps1` file.
All reusable functions live in `scripts/shared/`, script-specific logic lives in `helpers/`.

### Function Breakdown

| Function | Source | Purpose |
|----------|--------|---------|
| `Write-Log` | `shared/logging.ps1` | Prints a status-badged message and writes to transcript |
| `Write-Banner` | `shared/logging.ps1` | Displays ASCII banner blocks in a specified color |
| `Initialize-Logging` | `shared/logging.ps1` | Cleans and recreates `logs/`, starts transcript |
| `Import-JsonConfig` | `shared/logging.ps1` | Loads and returns a JSON file with verbose logging |
| `Backup-File` | `shared/json-utils.ps1` | Creates a timestamped backup of an existing file |
| `Merge-JsonDeep` | `shared/json-utils.ps1` | Recursively deep-merges two hashtables |
| `ConvertTo-OrderedHashtable` | `shared/json-utils.ps1` | Converts `PSCustomObject` to ordered hashtable |
| `Save-ResolvedData` | `shared/resolved.ps1` | Persists runtime-discovered state to `.resolved/` |
| `Resolve-SourceFiles` | `helpers/sync.ps1` | Scans for `.code-profile` first, falls back to individual JSON files |
| `Apply-Settings` | `helpers/sync.ps1` | Backs up and copies/merges `settings.json` |
| `Apply-Keybindings` | `helpers/sync.ps1` | Backs up and copies `keybindings.json` |
| `Install-Extensions` | `helpers/sync.ps1` | Installs extensions via VS Code CLI, checks `$LASTEXITCODE` |
| `Invoke-Edition` | `helpers/sync.ps1` | Orchestrates the full update for a single edition |

### Verbose Logging Rules

Every function MUST log:
- **What it is about to do** (the intent)
- **The values it is working with** (paths, keys, file sizes)
- **The outcome** (success, failure, skip, fallback)

Example: source file resolution must log which `.code-profile` was found,
what was extracted from it, and which fallback JSON files were used.

## Execution Flow

1. `Main` is called at the bottom of the script
2. Dot-source shared helpers (`git-pull.ps1`, `logging.ps1`, `json-utils.ps1`, `resolved.ps1`)
   - If `$env:SCRIPTS_ROOT_RUN` is `"1"` (set by root dispatcher), git pull is skipped
   - If run standalone, git pull executes normally
3. `Initialize-Logging` -- clean `logs/`, start transcript
4. `Import-JsonConfig` -- load `log-messages.json`, display banner
5. `Import-JsonConfig` -- load `config.json`, determine enabled editions
6. `Resolve-SourceFiles` -- find `.code-profile` or individual JSON files
7. Log merge/replace mode and extension count
8. For each enabled edition -> `Invoke-Edition`:
   a. Check CLI command availability (`code` / `code-insiders`)
   b. Resolve and create settings directory if needed
   c. `Save-ResolvedData` -- persist resolved settings dir + CLI command to `.resolved/`
   d. `Apply-Settings` -- backup existing, then copy or deep-merge
   e. `Apply-Keybindings` -- backup existing, then copy
   f. `Install-Extensions` -- install each extension via CLI (checks `$LASTEXITCODE`)
   g. Verify applied files exist at destination
9. Display summary footer

## Logging

- Each run creates a `logs/` subfolder inside the script directory
- The `logs/` folder is **deleted and recreated** at the start of every run
- A timestamped log file (`run-YYYYMMDD-HHmmss.log`) captures all terminal output
- The `logs` folder is already gitignored by the project-level `.gitignore`
- All file operations use `-Confirm:$false` to prevent interactive prompts
- **Every decision point** logs its inputs and outputs for easy debugging

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+**
- **VS Code installed** (Stable and/or Insiders)
- **VS Code CLI (`code` / `code-insiders`) in PATH**

## How to Run

```powershell
# From the project root (backup & replace, default):
.\run.ps1 -I 11

# Deep-merge settings into existing settings.json:
.\run.ps1 -I 11 -- -Merge

# Export current VS Code settings back to script folder:
.\run.ps1 -I 11 -- export
```

## Naming Conventions

| Rule | Example |
|------|---------|
| All file names use **lowercase-hyphenated** (kebab-case) | `run.ps1`, `log-messages.json`, `config.json` |
| Never use PascalCase or camelCase for file names | ~~`Sync-VSCodeSettings.ps1`~~ -> `run.ps1` |
| Folder names also use lowercase-hyphenated | `02-vscode-settings-sync`, `logs` |
| PowerShell functions inside scripts may use Verb-Noun PascalCase per PS convention | `Write-Log`, `Apply-Settings` |

## Design Decisions

| Decision                    | Rationale                                                    |
|-----------------------------|--------------------------------------------------------------|
| Small focused functions     | Each function does one thing; easy to test and debug         |
| Main entry point at bottom  | All functions defined first, single orchestration call       |
| Verbose logging at every step | Every path, value, and decision is logged for debugging    |
| Profile-first parsing       | Users can drop a .code-profile export and it just works     |
| Fallback to individual JSON | Flexibility -- users can also curate files manually          |
| Config is read-only at runtime | Scripts never mutate config.json -- keeps it declarative  |
| .resolved/ for runtime state | Resolved settings dirs and CLI info belong outside git     |
| Shared helpers in scripts/shared/ | Backup-File, Merge-JsonDeep etc. are reused across scripts |
| $LASTEXITCODE check on CLI  | Catches failed extension installs that don't throw exceptions |
| Keybindings support         | Profiles include keybindings; a complete import requires them |
| Separate extensions.json    | Easy to maintain extension list without editing script logic |
| Timestamp backup            | Never lose existing settings, multiple backups coexist       |
| Edition loop                | Single script handles both Stable and Insiders               |
| CLI-based extension install | Official supported method, no registry hacking needed        |
| No admin required           | Settings and extensions are per-user, no elevation needed    |
| Plain ASCII banners         | Avoids Unicode alignment bugs in terminals                   |
| Per-run log files           | Debugging aid; cleaned each run to avoid clutter             |
| -Confirm:$false on all ops  | Prevents interactive prompts that hang the script            |
| try/catch/finally in Main   | Ensures Stop-Transcript always runs, even on errors          |

## Install Keywords

| Keyword |
|---------|
| `vs-settings-sync` |
| `vssettingssync` |
| `vs-setting-sync` |
| `vssettingsync` |
| `settings-sync` |
| `settingssync` |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `vscode+settings` | 1, 11 |
| `vscode+s` | 1, 11 |
| `vscode+menu+settings` | 1, 10, 11 |
| `vms` | 1, 10, 11 |
| `web-dev` | 1, 3, 4, 7, 11 |
| `webdev` | 1, 3, 4, 7, 11 |
| `full-stack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `fullstack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `frontend` | 1, 3, 4, 11 |
| `essentials` | 1, 2, 3, 7, 11 |

```powershell
.\run.ps1 install vs-settings-sync
.\run.ps1 install vscode+settings
```
