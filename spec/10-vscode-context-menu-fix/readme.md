# Spec: VS Code Context Menu Fix

## Overview

A PowerShell utility that restores the **"Open with Code"** entry to the Windows
Explorer right-click context menu for files, folders, and folder backgrounds.

---

## Problem

After certain Windows updates or VS Code installations/reinstallations, the
context-menu entries for VS Code disappear. Users lose the ability to:

1. Right-click a **file** → "Open with Code"
2. Right-click a **folder** → "Open with Code"
3. Right-click the **background** of a folder (empty space) → "Open with Code"

## Solution

A structured PowerShell script that:

- Reads configuration (paths, labels) from an external **`config.json`**
- Reads all log/display messages from a separate **`log-messages.json`**
- Creates the required Windows Registry entries under `HKEY_CLASSES_ROOT`
- Provides colorful, structured terminal output with status badges

---

## File Structure

```
run.ps1                              # Root dispatcher (git pull + delegate)
scripts/
├── shared/
│   ├── git-pull.ps1                 # Shared git-pull helper (dot-sourced)
│   ├── logging.ps1                  # Write-Log, Write-Banner, Initialize-Logging, Import-JsonConfig
│   ├── json-utils.ps1               # Backup-File, Merge-JsonDeep, ConvertTo-OrderedHashtable
│   └── resolved.ps1                 # Save-ResolvedData, Get-ResolvedDir
└── 01-vscode-context-menu-fix/
    ├── config.json                  # Paths & settings (user-editable, never mutated at runtime)
    ├── log-messages.json            # All display strings & banners
    ├── run.ps1                      # Main script
    ├── helpers/
    │   ├── logging.ps1              # Script-specific logging (dot-sources shared)
    │   └── registry.ps1             # Registry & VS Code resolution helpers
    └── logs/                        # Auto-created runtime log folder (gitignored)
        └── run-<timestamp>.log      # Timestamped execution log

.resolved/                           # Runtime-resolved data (gitignored)
└── 01-vscode-context-menu-fix/
    └── resolved.json                # Cached exe paths, timestamps, username

spec/
├── shared/
│   └── readme.md                    # Shared helpers specification
└── 01-vscode-context-menu-fix/
    └── readme.md                    # This specification
```

## config.json Schema

`config.json` is **read-only at runtime**. Scripts never write back to it.
Runtime-discovered state goes to `.resolved/` instead.

| Key                  | Type   | Description                                        |
|----------------------|--------|----------------------------------------------------|
| `vscodePath.user`    | string | Path for per-user VS Code install (with env vars)  |
| `vscodePath.system`  | string | Path for system-wide VS Code install               |
| `registryPaths.file` | string | Registry key for file context menu                 |
| `registryPaths.directory` | string | Registry key for folder context menu          |
| `registryPaths.background` | string | Registry key for folder background menu     |
| `contextMenuLabel`   | string | Label shown in the context menu                    |
| `installationType`   | string | `"user"` or `"system"` — which path to try first   |

## .resolved/ Schema

Written automatically by the script to `.resolved/01-vscode-context-menu-fix/resolved.json`:

```json
{
  "stable": {
    "resolvedExe": "C:\\Program Files\\Microsoft VS Code\\Code.exe",
    "resolvedAt": "2026-04-03T18:10:02+08:00",
    "resolvedBy": "alim"
  },
  "insiders": {
    "resolvedExe": "C:\\Program Files\\Microsoft VS Code Insiders\\Code - Insiders.exe",
    "resolvedAt": "2026-04-03T18:10:05+08:00",
    "resolvedBy": "alim"
  }
}
```

On subsequent runs, `Resolve-VsCodePath` checks the cache first and skips
detection if the cached exe path still exists on disk.

## log-messages.json Schema

| Key       | Type     | Description                              |
|-----------|----------|------------------------------------------|
| `banner`  | string[] | ASCII art banner lines                   |
| `steps.*` | string   | Message for each step of the process     |
| `status.*`| string   | Badge labels: `[  OK  ]`, `[ FAIL ]` etc |
| `errors.*`| string   | Error message templates                  |
| `footer`  | string[] | Closing banner lines                     |

## Script Architecture

The script is organized into **small, focused functions** that are defined first,
then invoked from a single `Main` entry point at the bottom of the file.

### Function Breakdown

| Function | Purpose |
|----------|---------|
| `Write-Log` | Prints a status-badged message and writes to transcript |
| `Write-Banner` | Displays ASCII banner blocks |
| `Assert-Admin` | Returns `$true` if running as Administrator |
| `Initialize-Logging` | Cleans and recreates `logs/`, starts transcript |
| `Import-JsonConfig` | Loads and returns a JSON file with verbose logging |
| `Mount-RegistryDrive` | Maps `HKCR:` PSDrive if not already mapped |
| `Resolve-VsCodePath` | Resolves exe path with fallback, logs every step |
| `Register-ContextMenu` | Creates one registry entry (key + command subkey) |
| `Test-RegistryEntry` | Verifies a registry path exists after creation |
| `Invoke-Edition` | Processes a single edition (resolve, register, verify) |
| `Main` | Orchestrates the full flow -- called at the end of the file |

### Verbose Logging Rules

Every function MUST log:
- **What it is about to do** (the intent)
- **The values it is working with** (paths, keys, labels)
- **The outcome** (success, failure, skip, fallback)

Example: path resolution must log the raw config value, the expanded value,
whether the file exists, and which fallback (if any) was tried.

## Execution Flow

1. `Main` is called at the bottom of the script
2. Dot-source shared helpers (`git-pull.ps1`, `resolved.ps1`) and call `Invoke-GitPull`
   - If `$env:SCRIPTS_ROOT_RUN` is `"1"` (set by root dispatcher), git pull is skipped
   - If run standalone, git pull executes normally
3. `Initialize-Logging` -- clean `logs/`, start transcript
4. `Import-JsonConfig` -- load `log-messages.json`, display banner
5. `Assert-Admin` -- verify Administrator privileges
6. `Import-JsonConfig` -- load `config.json`
7. `Mount-RegistryDrive` -- map `HKCR:` PSDrive (with `-Scope Global`)
8. For each enabled edition -> `Invoke-Edition`:
   a. `Resolve-VsCodePath` -- **check `.resolved/` cache first**, then detect with fallback
   b. `Save-ResolvedData` -- persist discovered path to `.resolved/`
   c. `Register-ContextMenu` -- create 3 registry entries
   d. `Test-RegistryEntry` -- verify each entry
9. Display summary footer

## Logging

- Each run creates a `logs/` subfolder inside the script directory
- The `logs/` folder is **deleted and recreated** at the start of every run
- A timestamped log file (`run-YYYYMMDD-HHmmss.log`) captures all terminal output
- The `logs` folder is already gitignored by the project-level `.gitignore`
- All `New-Item` and `Set-ItemProperty` calls use `-Confirm:$false` to prevent hangs
- **Every decision point** logs its inputs and outputs for easy debugging

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+**
- **Administrator privileges**
- **VS Code installed** (user or system)

## How to Run

```powershell
# Open PowerShell as Administrator, then:
cd scripts\01-vscode-context-menu-fix
.\run.ps1
```

## Naming Conventions

| Rule | Example |
|------|---------|
| All file names use **lowercase-hyphenated** (kebab-case) | `run.ps1`, `log-messages.json`, `config.json` |
| Never use PascalCase or camelCase for file names | ~~`Fix-VSCodeContextMenu.ps1`~~ → `run.ps1` |
| Folder names also use lowercase-hyphenated | `01-vscode-context-menu-fix`, `logs` |
| PowerShell functions inside scripts may use Verb-Noun PascalCase per PS convention | `Write-Log`, `Assert-Admin` |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Small focused functions | Each function does one thing; easy to test and debug |
| Main entry point at bottom | All functions defined first, single orchestration call |
| Verbose logging at every step | Every path, value, and decision is logged for debugging |
| External JSON configs | Easy to edit without touching script logic |
| Config is read-only at runtime | Scripts never mutate config.json -- keeps it declarative and git-friendly |
| .resolved/ for runtime state | Discovered paths, timestamps belong outside version control |
| Cache-first path detection | Checks .resolved/ before probing filesystem, skips if cached path is still valid |
| Env-var expansion at runtime | Supports both user & system installs portably |
| Auto-fallback path detection | Reduces user friction if wrong type is selected |
| Colored status badges | Clear visual feedback in the terminal |
| Plain ASCII banners | Avoids Unicode alignment bugs in terminals |
| Per-run log files | Debugging aid; cleaned each run to avoid clutter |
| -Confirm:$false on all registry ops | Prevents interactive prompts that hang the script |

## Install Keywords

| Keyword |
|---------|
| `vs-context-menu` |
| `vscontextmenu` |
| `context-menu` |
| `contextmenu` |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `vscode+menu+settings` | 1, 10, 11 |
| `vms` | 1, 10, 11 |

```powershell
.\run.ps1 install vs-context-menu
.\run.ps1 install vscode+menu+settings
```
