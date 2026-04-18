# Spec: Script 36 -- Install OBS Studio

## Purpose

Install OBS Studio via Chocolatey and/or sync curated scene collections
and profiles from the bundled settings zip. Supports three modes.

## Naming Convention

| Shortcut Label | Meaning | Keyword |
|----------------|---------|---------|
| **OBS + Settings** | Install OBS and sync settings | `obs+settings`, `obs` |
| **OBS Settings** | Sync settings only (no install) | `obs-settings` |
| **Install OBS** | Install only (no settings sync) | `install-obs` |

## Usage

```powershell
.\run.ps1 install obs              # OBS + Settings (default)
.\run.ps1 install obs+settings     # OBS + Settings (explicit)
.\run.ps1 install obs-settings     # OBS Settings only
.\run.ps1 install install-obs      # Install OBS only
.\run.ps1 -I 36 -- export         # Export settings from machine to repo
.\run.ps1 -I 36                    # OBS + Settings (default mode)
.\run.ps1 -I 36 -- -Mode settings-only   # OBS Settings only
.\run.ps1 -I 36 -- -Mode install-only    # Install OBS only
```

## Settings Package

The settings zip lives in the shared settings folder:
- `settings/02 - obs-settings/*.zip`

The first `.zip` found in that directory is used.

### Sync Process

1. Extract the zip to a **temp directory** (`%TEMP%\obs-settings-extract-<timestamp>`)
2. Copy all `.json` files (scene collections) to `%APPDATA%\obs-studio\basic\scenes\`
3. Copy all subdirectories (profiles) to `%APPDATA%\obs-studio\basic\profiles\`
4. Clean up the temp directory

OBS Studio automatically discovers scene collections and profiles from these
directories on startup -- no CLI import command is needed.

### Important: Settings always sync

When the install check finds OBS is already installed (via `.installed/obs.json`),
the install step is skipped but **settings sync still runs** in `install+settings`
mode. This is intentional -- the user may want to restore corrupted or changed settings.

### Zip Contents (example)

```
01__Alim_2023_v10__Gaming__Audio_Best.json     # Scene collection -> basic\scenes\
02__Alim_2024_v10__Single_Recorder.json        # Scene collection -> basic\scenes\
03_Interview.json                              # Scene collection -> basic\scenes\
...
Alim_Workstation_11_Pro_Profile_2024/          # Profile folder   -> basic\profiles\
  basic.ini
```

## Modes

### install+settings (OBS + Settings)

1. Install OBS Studio via Chocolatey (if not already installed)
2. Verify installation
3. Extract zip to temp, copy scenes + profiles to AppData

### settings-only (OBS Settings)

1. Skip OBS installation entirely
2. Extract zip to temp, copy scenes + profiles to AppData

### install-only (Install OBS)

1. Install OBS Studio via Chocolatey (if not already installed)
2. Verify installation
3. Skip settings sync

## Mode Resolution Order

1. `-Mode` parameter on `run.ps1` (highest priority)
2. `$env:OBS_MODE` environment variable (set by keyword resolver)
3. Default: `install+settings`

## Config (`config.json`)

| Key | Type | Purpose |
|-----|------|---------|
| `obs.enabled` | bool | Toggle script |
| `obs.chocoPackage` | string | Chocolatey package name (`obs-studio`) |
| `obs.syncSettings` | bool | Whether to copy settings after install |
| `obs.defaultMode` | string | Default mode when not specified |

## Verification Paths

- `$env:ProgramFiles\obs-studio\bin\64bit\obs64.exe`
- `${env:ProgramFiles(x86)}\obs-studio\bin\64bit\obs64.exe`

## Log Messages

Defined in `log-messages.json`. Key messages:
- `alreadyInstalled` -- shown when OBS version matches tracked record
- `syncingSettings` / `settingsSynced` -- settings extraction progress
- `settingsSkipped` -- no settings files found in settings source

## Helpers

| File | Function | Purpose |
|------|----------|---------|
| `obs.ps1` | `Install-OBS` | Install via Chocolatey, verify, track (accepts `-Mode`) |
| `obs.ps1` | `Sync-OBSSettings` | Extract zip to temp, copy scenes + profiles to AppData |
| `obs.ps1` | `Export-OBSSettings` | Export scenes + profiles from AppData back to repo |

## Settings Export

The export command copies OBS settings FROM the machine back INTO the repo:

```powershell
.\run.ps1 -I 36 -- export
```

**Source:** `%APPDATA%\obs-studio\basic\scenes\` and `%APPDATA%\obs-studio\basic\profiles\`
**Target:** `settings/02 - obs-settings/`

Safety rules:
- Only `.json` scene collections are exported (no binaries)
- Files larger than 512 KB are skipped
- Profile folders are exported recursively

## Install Keywords

| Keyword | Mode |
|---------|------|
| `obs` | install+settings |
| `obs-studio` | install+settings |
| `obs+settings` | install+settings |
| `obs-settings` | settings-only |
| `install-obs` | install-only |

```powershell
.\run.ps1 install obs
```
