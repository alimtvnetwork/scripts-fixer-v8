# Spec: Script 05 -- Install Python

## Purpose

Install Python via Chocolatey and configure `PYTHONUSERBASE` so that
`pip install --user` targets the shared dev directory.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install Python + configure pip (default) |
| `install` | Install/upgrade Python only |
| `configure` | Configure pip site and PATH only |
| `uninstall` | Uninstall Python, remove env vars, clean dev dir, purge tracking |
| `-Help` | Show usage information |

## Parameters

| Parameter | Position | Description |
|-----------|----------|-------------|
| `-Path` | 1 (after command) | Custom dev directory path. Overrides smart drive detection and `$env:DEV_DIR`. All pip site configuration uses this path. |

### Usage with -Path

```powershell
.\run.ps1 all F:\dev-tool           # Install + configure pip to F:\dev-tool\python
.\run.ps1 install D:\projects  # Install Python, dev dir set to D:\projects
.\run.ps1 -Path E:\dev-tool         # Same as: .\run.ps1 all E:\dev
.\run.ps1 configure G:\tools   # Configure pip site to G:\tools\python
```

When `-Path` is provided, the script skips smart drive detection entirely
and uses the given path as the dev directory. The pip user site will be
set to `<Path>\python` (the `devDirSubfolder` from config.json).

## Uninstall

The `uninstall` subcommand performs a full cleanup:

1. **Chocolatey uninstall** -- removes the Python package and its dependencies
2. **Environment variable** -- removes `PYTHONUSERBASE` from User scope
3. **PATH cleanup** -- removes the `Scripts\` directory from User PATH
4. **Dev directory** -- deletes the `<devDir>\python` subfolder and all its contents
5. **Tracking records** -- purges `.installed/python.json` and `.resolved/05-install-python/`

```powershell
.\run.ps1 uninstall            # Full uninstall with smart dev dir detection
.\run.ps1 uninstall E:\dev-tool     # Uninstall, clean E:\dev-tool\python specifically
```

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `chocoPackageName` | string | Chocolatey package (`python3`) |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `devDirSubfolder` | string | Subfolder under dev dir |
| `installer.version` | string | Python version to install (e.g. `3.13.5`) |
| `installer.downloadUrl` | string | Official python.org installer URL |
| `installer.fileName` | string | Installer exe filename |
| `installer.installDirSubfolder` | string | Subfolder under `<devDir>/python/` (e.g. `Python313`) |
| `installer.allUsers` | bool | Install for all users |
| `installer.includePip` | bool | Include pip in installation |
| `pip.setUserSite` | bool | Whether to set PYTHONUSERBASE |
| `path.updateUserPath` | bool | Add Scripts dir to PATH |
| `path.ensurePipInPath` | bool | Ensure pip is reachable |

## Smart Drive Detection

When no `-Path` is provided and `$env:DEV_DIR` is not set, the script
automatically selects the best drive for the Python install directory:

1. **E: drive** (preferred)
2. **D: drive** (secondary)
3. **Any other non-system fixed drive** with the most free space (minimum 10 GB)
4. **Prompt the user** if no drive qualifies

The install directory becomes `<bestDrive>:\dev-tool\python\Python313`.
Users can always override with `-Path`.

## Flow

1. Assert admin + Chocolatey
2. Install/upgrade Python via Chocolatey
3. Set `PYTHONUSERBASE` env var to dev dir subfolder
4. Add `Scripts\` to User PATH
5. Save resolved state

## Install Keywords

| Keyword | Scripts | Description |
|---------|---------|-------------|
| `python` | 05 | Install Python + pip |
| `pip` | 05 | Install Python + pip |
| `python-pip` | 05 | Install Python + pip |
| `pythonpip` | 05 | Install Python + pip |
| `python+pip` | 05 | Install Python + pip |
| `pylibs` | 05, 41 | Python + all pip libraries (numpy, pandas, jupyter, etc.) |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts | Description |
|---------|---------|-------------|
| `full-stack` | 01-09, 11, 16, 39, 40 | Everything for full-stack dev |
| `fullstack` | 01-09, 11, 16, 39, 40 | Everything for full-stack dev |
| `backend` | 05, 06, 16, 20, 39, 40 | Python + Go + PHP + PG + .NET + Java |
| `python+libs` | 05, 41 | Python + all libraries |
| `ml-dev` | 05, 41 | Python + all libraries |
| `data-science` | 05, 41 | Python + data/viz libs |
| `ai-dev` | 05, 41 | Python + ML libs |

```powershell
.\run.ps1 install python
.\run.ps1 install pylibs             # Python + all pip libraries in one go
.\run.ps1 install full-stack
.\run.ps1 install backend
```
