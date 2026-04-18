# Spec: Install DBeaver Community

## Overview

Installs DBeaver Community Edition, a universal database visualization and
management tool that supports MySQL, PostgreSQL, SQLite, MongoDB, Redis,
and many other databases. Optionally syncs connection profiles and settings
from a local settings folder.

## What It Does

1. Checks if DBeaver is already installed (PATH + common install locations)
2. Installs DBeaver Community via Chocolatey (`choco install dbeaver`)
3. Refreshes PATH and verifies the install
4. Syncs settings from `settings/04 - dbeaver/` to `%APPDATA%\DBeaverData\workspace6\General\.dbeaver\`
5. Saves resolved state to `.resolved/32-install-dbeaver/resolved.json`

## Modes

| Mode | Description |
|------|-------------|
| `install+settings` | Install DBeaver + sync settings (default) |
| `settings-only` | Sync settings only (no admin required) |
| `install-only` | Install DBeaver only (skip settings sync) |

## Configuration

| Key | Purpose |
|-----|---------|
| `database.enabled` | Enable/disable the install |
| `database.chocoPackage` | Chocolatey package name (`dbeaver`) |
| `database.verifyCommand` | CLI command to verify install (`dbeaver-cli`) |
| `database.syncSettings` | Enable/disable settings sync |
| `database.defaultMode` | Default mode (`install+settings`) |

## Settings Sync

The settings sync feature copies configuration files from the repo's
`settings/04 - dbeaver/` folder to DBeaver's data directory:

```
%APPDATA%\DBeaverData\workspace6\General\.dbeaver\
```

Supported files:
- `data-sources.json` -- Connection profiles
- `credentials-config.json` -- Encrypted credential store
- Any subdirectories (drivers, templates, etc.)

## Settings Export

The export command copies settings FROM the machine back INTO the repo for
backup and version control:

```powershell
.\run.ps1 -I 32 -- export
```

**Source:** `%APPDATA%\DBeaverData\workspace6\General\.dbeaver\`
**Target:** `settings/04 - dbeaver/`

Safety rules:
- Only `.json` config files are exported (no binaries)
- Files larger than 512 KB are skipped (likely cache, not config)
- `readme.txt` is preserved in the target directory
- Subdirectories (drivers, templates) are exported recursively

## Usage

```powershell
.\run.ps1 -I 32                        # Install DBeaver + sync settings
.\run.ps1 install dbeaver              # Install via keyword (default mode)
.\run.ps1 install dbeaver-settings     # Sync settings only
.\run.ps1 install install-dbeaver      # Install only (no settings)
.\run.ps1 -I 32 -- export             # Export settings from machine to repo
.\run.ps1 -I 32 -- -Help              # Show help
.\run.ps1 -I 32 -- -Mode settings-only # Explicit mode
```

## Notes

- DBeaver Community is free and open-source (Apache 2.0 license)
- The `dbeaver-cli` command may not be in PATH on all systems; the installer
  also checks `Program Files\DBeaver\` as a fallback
- Settings-only mode does not require admin privileges
- Pairs well with database installs (SQLite, MySQL, PostgreSQL, etc.)

## Install Keywords

| Keyword | Mode |
|---------|------|
| `dbeaver` | install+settings |
| `db-viewer` | install+settings |
| `dbviewer` | install+settings |
| `dbeaver+settings` | install+settings |
| `dbeaver-settings` | settings-only |
| `install-dbeaver` | install-only |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `data-dev` | 20, 24, 28, 32 |
| `datadev` | 20, 24, 28, 32 |

```powershell
.\run.ps1 install dbeaver
.\run.ps1 install data-dev
```
