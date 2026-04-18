# Spec: Dev Environment Setup Scripts (01-10)

## Overview

A suite of PowerShell scripts that set up a complete Windows development
environment from scratch. Each script handles one concern and can run
standalone or be orchestrated by script 04.

All dev tools are installed into a configurable **dev directory** (default: `E:\dev`)
with structured subdirectories per tool.

---

## Script Inventory

| Script | Folder | Purpose | Requires Admin |
|--------|--------|---------|----------------|
| 01 | `01-vscode-context-menu-fix` | Restore "Open with Code" context menu entries | Yes |
| 02 | `02-vscode-settings-sync` | Import VS Code settings, keybindings, extensions | No |
| 03 | `03-install-package-managers` | Install/update Chocolatey + Winget | Yes |
| 04 | `04-install-all-dev-tools` | Orchestrator: runs 03, 05-10 in sequence | Yes |
| 05 | `05-install-golang` | Install Go via Choco, configure GOPATH + go env | Yes |
| 06 | `06-install-nodejs` | Install Node.js via Choco, configure npm prefix | Yes |
| 07 | `07-install-python` | Install Python via Choco, configure pip | Yes |
| 08 | `08-install-pnpm` | Install + configure pnpm (global store in dev dir) | No |
| 09 | `09-install-git` | Install Git + Git LFS + GitHub CLI, configure settings | Yes |
| 10 | `10-install-github-desktop` | Install GitHub Desktop via Choco | Yes |

---

## Shared Dev Directory Structure

```
E:\dev\                                # Configurable root (default E:\dev)
├── go\                                # GOPATH
│   ├── bin\                           # Go binaries (added to PATH)
│   ├── pkg\mod\                       # GOMODCACHE
│   └── cache\build\                   # GOCACHE
├── nodejs\                            # Node.js custom install prefix
│   └── node_modules\                  # Global modules
├── python\                            # Python user site / virtualenvs
│   └── Scripts\                       # pip scripts (added to PATH)
└── pnpm\                              # pnpm global store
    └── store\                         # Content-addressable store
```

---

## Shared Helpers (scripts/shared/)

| File | Functions | Purpose |
|------|-----------|---------|
| `logging.ps1` | `Write-Log`, `Write-Banner` | Colorful logging with level badges |
| `resolved.ps1` | `Save-ResolvedData`, `Import-JsonConfig` | JSON config loading + state persistence |
| `git-pull.ps1` | `Invoke-GitPull` | Auto-pull latest scripts on run |
| `help.ps1` | `Show-ScriptHelp` | Standardized --help output |
| `path-utils.ps1` | `Add-ToUserPath`, `Add-ToMachinePath`, `Test-InPath` | Safe PATH manipulation with dedup |
| `choco-utils.ps1` | `Assert-Choco`, `Install-ChocoPackage`, `Upgrade-ChocoPackage` | Chocolatey wrappers with logging |
| `dev-dir.ps1` | `Resolve-DevDir`, `Initialize-DevDir` | Dev directory resolution + creation |
| `json-utils.ps1` | JSON merge utilities | Deep-merge for settings sync |
| `cleanup.ps1` | Cleanup utilities | Post-run cleanup |

---

## Script 03: install-package-managers

### Purpose
Install and/or update Chocolatey and Winget package managers.

### Subcommands
```powershell
.\run.ps1 choco              # Install/update Chocolatey only
.\run.ps1 winget             # Install/verify Winget only
.\run.ps1 all                # Install both (default)
.\run.ps1 -Help              # Show available commands
```

---

## Script 04: install-golang

### Purpose
Install Go via Chocolatey, configure GOPATH, GOMODCACHE, GOCACHE, GOPROXY,
GOPRIVATE, and update PATH.

### Subcommands
```powershell
.\run.ps1                    # Install + configure (default "all")
.\run.ps1 install            # Install/upgrade Go only
.\run.ps1 configure          # Configure GOPATH/env only
.\run.ps1 -Help              # Show usage
```

---

## Script 05: install-nodejs

### Purpose
Install Node.js (LTS) via Chocolatey, configure npm global prefix inside dev dir.

### Subcommands
```powershell
.\run.ps1                    # Install + configure (default)
.\run.ps1 install            # Install/upgrade only
.\run.ps1 configure          # Configure npm prefix only
.\run.ps1 -Help              # Show usage
```

---

## Script 06: install-python

### Purpose
Install Python via Chocolatey, configure pip user site inside dev dir.

### Subcommands
```powershell
.\run.ps1                    # Install + configure (default)
.\run.ps1 install            # Install/upgrade only
.\run.ps1 configure          # Configure pip only
.\run.ps1 -Help              # Show usage
```

---

## Script 07: install-pnpm

### Purpose
Install pnpm globally and configure the global store inside dev dir.

### Subcommands
```powershell
.\run.ps1                    # Install + configure (default)
.\run.ps1 install            # Install only
.\run.ps1 configure          # Configure store only
.\run.ps1 -Help              # Show usage
```

---

## Script 09: install-git

### Purpose
Install Git, Git LFS, and GitHub CLI via Chocolatey. Configure global git
settings including user identity, default branch, credential manager,
line endings, editor, and push behavior.

### Subcommands
```powershell
.\run.ps1                    # Install all + configure (default)
.\run.ps1 install            # Install Git + LFS + gh only
.\run.ps1 configure          # Configure settings + PATH only
.\run.ps1 -Help              # Show usage
```

---

## Script 10: install-github-desktop

### Purpose
Install GitHub Desktop via Chocolatey.

### Subcommands
```powershell
.\run.ps1                    # Install (default)
.\run.ps1 -Help              # Show usage
```

---

## Script 04: install-all-dev-tools

### Purpose
Orchestrator that runs scripts 03, 05-10 in sequence. Resolves the dev directory
once, passes it to all child scripts via `$env:DEV_DIR`.

### Sequence
`03 (Package Managers) > 09 (Git + LFS + gh) > 04 (Go) > 05 (Node.js) > 06 (Python) > 07 (pnpm) > 10 (GitHub Desktop)`

### Subcommands
```powershell
.\run.ps1                    # Run all (default)
.\run.ps1 -Skip "05,07"     # Skip Node.js and pnpm
.\run.ps1 -Only "03,04"     # Run only package managers + Go
.\run.ps1 -Help              # Show available commands
```

---

## --help Convention

Every script supports `-Help` which prints:
- Script name and version
- One-line description
- Available subcommands with descriptions
- Example usage

---

## Conventions (all scripts follow)

| Convention | Detail |
|------------|--------|
| Shared helpers | Dot-source from `scripts/shared/` |
| Script helpers | `helpers/` subfolder per script |
| Config files | `config.json` (read-only at runtime) |
| Log messages | `log-messages.json` for all display strings |
| Runtime state | `.resolved/<script-folder>/resolved.json` |
| Logging | Shared `Write-Log -Level` with status badges |
| Banner | `Write-Banner -Title -Version` |
| Help | `Show-ScriptHelp -LogMessages` |
| Admin check | Inline check with `$logMessages.messages.notAdmin` |
| PATH safety | Dedup before adding, user PATH preferred |
| Dev dir | All tools install into `$env:DEV_DIR` subfolders |
| No hardcoded paths | Everything in config.json with env var expansion |
