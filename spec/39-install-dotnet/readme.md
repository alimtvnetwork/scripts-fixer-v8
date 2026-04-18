# Spec: Script 39 -- Install .NET SDK

## Purpose

Install .NET SDK via Chocolatey with version selection support.
Users can install the latest SDK or a specific LTS/STS version.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install .NET SDK + configure PATH (default) |
| `install` | Install .NET SDK only |
| `install <version>` | Install a specific .NET SDK version |
| `uninstall` | Uninstall all .NET SDKs, clean PATH, purge tracking |
| `-Help` | Show usage information |

## Parameters

| Parameter | Position | Description |
|-----------|----------|-------------|
| `-Path` | 1 (after command) | Custom dev directory path. Overrides `$env:DEV_DIR`. |

## Version Selection

| Version | Choco Package | Description |
|---------|---------------|-------------|
| `latest` | `dotnet-sdk` | Newest stable SDK (default) |
| `6` | `dotnet-6.0-sdk` | .NET 6 LTS |
| `8` | `dotnet-8.0-sdk` | .NET 8 LTS |
| `9` | `dotnet-9.0-sdk` | .NET 9 STS |

### Usage Examples

```powershell
.\run.ps1 -I 39                    # Install latest .NET SDK
.\run.ps1 -I 39 -- install 8      # Install .NET 8 LTS
.\run.ps1 -I 39 -- install 6      # Install .NET 6 LTS
.\run.ps1 -I 39 -- install 9      # Install .NET 9 STS
.\run.ps1 -I 39 -- uninstall      # Full uninstall + cleanup
.\run.ps1 install dotnet           # Via keyword (latest)
.\run.ps1 install dotnet-8         # Via keyword (.NET 8)
.\run.ps1 install csharp           # Via keyword (latest)
```

## Uninstall

The `uninstall` subcommand performs a full cleanup:

1. **Chocolatey uninstall** -- removes all .NET SDK packages
2. **PATH cleanup** -- removes dev directory from User PATH
3. **Dev directory** -- deletes `<devDir>\dotnet` subfolder
4. **Tracking records** -- purges `.installed/dotnet-*.json` and `.resolved/39-install-dotnet/`

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `chocoPackages` | object | Maps version keys to Chocolatey package names |
| `defaultVersion` | string | Version to install when none specified |
| `availableVersions` | array | Valid version keys |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `devDirSubfolder` | string | Subfolder under dev dir |
| `path.updateUserPath` | bool | Add dotnet dir to PATH |

## Flow

1. Assert admin + Chocolatey
2. Log install target directory
3. Resolve requested version (default: latest)
4. Install/upgrade .NET SDK via Chocolatey
5. Add dev dir to User PATH
6. Save resolved state (dotnet --version, --list-sdks)

## Install Keywords

| Keyword |
|---------|
| `dotnet` |
| `.net` |
| `dotnet-sdk` |
| `csharp` |
| `c#` |
| `dotnet-6` |
| `dotnet-8` |
| `dotnet-9` |
