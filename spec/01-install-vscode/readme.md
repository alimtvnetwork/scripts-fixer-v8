# Spec: Install VS Code (Script 01)

## Overview

Installs Visual Studio Code via Chocolatey. Supports Stable and Insiders
editions with a runtime prompt for edition selection.

## Features

- Installs VS Code Stable and/or Insiders via Chocolatey
- Runtime edition prompt (Stable / Insiders / Both)
- Upgrades existing installations to latest version
- Can bypass prompt via subcommand (`stable`, `insiders`)

## Config (`config.json`)

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `editions.stable.enabled` | bool | Include Stable when not prompting |
| `editions.stable.chocoPackageName` | string | Chocolatey package name |
| `editions.insiders.enabled` | bool | Include Insiders when not prompting |
| `editions.insiders.chocoPackageName` | string | Chocolatey package name |
| `promptEdition` | bool | Show interactive edition picker |

## Usage

```powershell
.\run.ps1              # Interactive edition prompt
.\run.ps1 stable       # Install only Stable
.\run.ps1 insiders     # Install only Insiders
.\run.ps1 -Help        # Show help
```

## Dependencies

- Administrator privileges
- Chocolatey (auto-installed via `Assert-Choco`)

## Install Keywords

| Keyword |
|---------|
| `vscode` |
| `vs-code` |
| `code` |

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
.\run.ps1 install vscode
.\run.ps1 install vscode+settings
```
