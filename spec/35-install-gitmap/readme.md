# Install GitMap (Script 35)

## Overview

Script 35 installs the **GitMap CLI** -- a Git repository navigator tool for Windows. It uses the remote installer from GitHub (`alimtvnetwork/gitmap-v3`).

## Install Command

```powershell
# Via run.ps1
.\run.ps1 install gitmap
.\run.ps1 -I 35

# Pin a specific release version (overrides config.fallbackTag at runtime)
.\run.ps1 -I 35 -Version v1.2.0
.\run.ps1 install gitmap -Version v1.0.0

# Direct remote install (standalone)
irm https://raw.githubusercontent.com/alimtvnetwork/gitmap-v3/main/gitmap/scripts/install.ps1 | iex
```

## `--Version` Flag

Pin gitmap to a specific release tag. When provided, the value overrides
`gitmap.fallbackTag` from `config.json` for this run only (config file is not
modified). The pinned tag is used by the ZIP fallback path when the remote
installer fails or is unreachable.

| Example | Behavior |
|---------|----------|
| `.\run.ps1 -I 35` | Uses `fallbackTag` from config (default `latest`) |
| `.\run.ps1 -I 35 -Version v1.2.0` | Forces tag `v1.2.0` for this run |
| `.\run.ps1 install gitmap -Version v1.0.0` | Same, via dispatcher keyword |
| `.\run.ps1 -I 35 -- -Help` | Shows help including `-Version` flag |

Notes:
- Tag must match an existing release in `alimtvnetwork/gitmap-v3` (e.g. `v1.2.0`).
- Use `latest` to resolve the newest release via the GitHub API.
- The flag has no effect if the remote installer succeeds and pins its own version internally.

## Config (`config.json`)

| Key                  | Description                                |
|----------------------|--------------------------------------------|
| `devDir.mode`        | Drive resolution mode (`smart` or legacy)  |
| `devDir.default`     | Default install directory                  |
| `devDir.override`    | Force a specific directory (overrides all) |
| `gitmap.enabled`     | Enable/disable GitMap install              |
| `gitmap.verifyCommand` | Command to check if GitMap is installed  |
| `gitmap.installUrl`  | URL to the remote install.ps1              |
| `gitmap.repo`        | GitHub repository                          |
| `gitmap.releaseZipUrl` | URL template for ZIP fallback (`{tag}` placeholder) |
| `gitmap.fallbackTag` | Tag for ZIP fallback (`latest` resolves via API) |
| `gitmap.installDir`  | Override install directory (bypasses devDir)|

Default install directory: `C:\dev-tool\GitMap` (resolved via `devDir` config).

## Install Directory Resolution

Priority order:
1. `gitmap.installDir` -- explicit override in config
2. `Resolve-DevDir` -- uses `$env:DEV_DIR`, smart drive detection (E: > D: > best drive), or user prompt
3. `devDir.default` -- legacy fallback from config
4. Hardcoded `C:\dev-tool\GitMap`

The resolved path is passed as `-InstallDir` to the remote installer script.

## Remote Installer Flags

| Flag           | Description                          | Example                          |
|----------------|--------------------------------------|----------------------------------|
| `-InstallDir`  | Custom install directory             | `-InstallDir C:\tools\gitmap`    |
| `-Version`     | Pin a specific release               | `-Version v2.49.1`              |
| `-Arch`        | Force architecture (amd64, arm64)    | `-Arch arm64`                   |
| `-NoPath`      | Skip adding to user PATH             | `-NoPath`                       |

## Detection

1. Checks `gitmap` in PATH (`Get-Command`)
2. Falls back to known install paths: `$env:LOCALAPPDATA\gitmap\gitmap.exe` and `C:\dev-tool\GitMap\gitmap.exe`
3. Also checks devDir-resolved path: `$env:DEV_DIR\GitMap\gitmap.exe`

## How It Works

1. Checks if GitMap is already installed
2. If not found, resolves install directory via devDir system
3. Downloads `install.ps1` from GitHub via `Invoke-RestMethod`
4. Executes the installer script with `-InstallDir <resolved-path>`
5. **If remote installer fails** -- falls back to ZIP download:
   - Resolves tag via GitHub API (or uses `fallbackTag` from config)
   - Downloads `gitmap-windows-amd64.zip` from releases
   - Extracts `gitmap.exe` to install directory
   - Adds install directory to user PATH
6. Refreshes PATH and verifies installation
7. Saves resolved state (includes installDir)

## Keywords

`gitmap`, `git-map`

## Install Keywords

| Keyword |
|---------|
| `gitmap` |
| `git-map` |

```powershell
.\run.ps1 install gitmap
```
