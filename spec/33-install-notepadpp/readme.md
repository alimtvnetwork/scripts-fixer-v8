# Spec: Script 33 -- Install Notepad++

## Purpose

Install Notepad++ text editor via Chocolatey and/or sync curated settings
from the bundled zip to the user's AppData directory. Supports three modes.

## Naming Convention

| Shortcut Label | Meaning | Keyword |
|----------------|---------|---------|
| **NPP + Settings** | Install Notepad++ and sync settings | `npp+settings`, `notepad++`, `npp` |
| **NPP Settings** | Sync settings only (no install) | `npp-settings` |
| **Install NPP** | Install only (no settings sync) | `install-npp` |

> **NPP** always means **Notepad++**.

## Usage

```powershell
.\run.ps1 install npp              # NPP + Settings (default)
.\run.ps1 install npp+settings     # NPP + Settings (explicit)
.\run.ps1 install npp-settings     # NPP Settings only
.\run.ps1 install install-npp      # Install NPP only
.\run.ps1 -I 33 -- export         # Export settings from machine to repo
.\run.ps1 -I 33                    # NPP + Settings (default mode)
.\run.ps1 -I 33 -- -Mode settings-only   # NPP Settings only
.\run.ps1 -I 33 -- -Mode install-only    # Install NPP only
```

## Settings Package

The settings are bundled as `scripts/33-install-notepadpp/settings/notepadpp-settings.zip`.

The zip is extracted to the user-specific roaming path:
- `%APPDATA%\Notepad++\` (resolves to `C:\Users\{user}\AppData\Roaming\Notepad++\`)

This is a **full replace** -- all files in the zip overwrite whatever exists
in the target directory. Contents include: config.xml, themes, shortcuts,
function lists, plugins config, user-defined languages.

## Modes

### install+settings (NPP + Settings)

1. Install Notepad++ via Chocolatey (if not already installed)
2. Verify installation
3. Extract settings zip to `%APPDATA%\Notepad++\`

### settings-only (NPP Settings)

1. Skip Notepad++ installation entirely
2. Extract settings zip to `%APPDATA%\Notepad++\`

### install-only (Install NPP)

1. Install Notepad++ via Chocolatey (if not already installed)
2. Verify installation
3. Skip settings sync

## Mode Resolution Order

1. `-Mode` parameter on `run.ps1` (highest priority)
2. `$env:NPP_MODE` environment variable (set by keyword resolver)
3. Default: `install+settings`

## Config (`config.json`)

| Key | Type | Purpose |
|-----|------|---------|
| `notepadpp.enabled` | bool | Toggle script |
| `notepadpp.chocoPackage` | string | Chocolatey package name |
| `notepadpp.syncSettings` | bool | Whether to copy settings after install |
| `notepadpp.defaultMode` | string | Default mode when not specified |

## Log Messages

Defined in `log-messages.json`. Key messages:
- `alreadyInstalled` -- shown when Notepad++ version matches tracked record
- `syncingSettings` / `settingsSynced` -- settings extraction progress
- `settingsSkipped` -- no settings files found in script folder

## Helpers

| File | Function | Purpose |
|------|----------|---------|
| `notepadpp.ps1` | `Install-NotepadPP` | Install via Chocolatey, verify, track (accepts `-Mode`) |
| `notepadpp.ps1` | `Sync-NotepadPPSettings` | Extract settings zip to AppData |
| `notepadpp.ps1` | `Export-NotepadPPSettings` | Export settings from AppData back to repo |

## Settings Export

The export command copies Notepad++ settings FROM the machine back INTO the repo:

```powershell
.\run.ps1 -I 33 -- export
```

**Source:** `%APPDATA%\Notepad++\`
**Target:** `settings/01 - notepad++/`

Safety rules:
- Config files exported: `.xml`, `.json`, `.ini`, `.txt`
- Files larger than 512 KB are skipped (likely cache)
- `readme.txt` is preserved in the target directory
- Subdirectories exported recursively (themes, userDefineLangs, etc.)
- Runtime folders skipped: `backup`, `session`, `plugins`

## Install Keywords

| Keyword | Mode |
|---------|------|
| `notepad++` | install+settings |
| `notepadpp` | install+settings |
| `notepad-plus` | install+settings |
| `npp` | install+settings |
| `npp+settings` | install+settings |
| `npp-settings` | settings-only |
| `install-npp` | install-only |

```powershell
.\run.ps1 install notepad++
```
