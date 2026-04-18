# Spec: Script 24 -- Install Redis

## Purpose

Installs Redis with flexible installation path options.
In-memory key-value store and cache.

## Usage

```powershell
.\run.ps1          # Install Redis (interactive path prompt)
.\run.ps1 -Help    # Show usage
```

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `devDir.mode` | string | Resolution mode (json-or-prompt) |
| `devDir.default` | string | Default dev directory path |
| `devDir.override` | string | Hard override (skips prompt) |
| `installMode.default` | string | Default install location (devDir/custom/system) |
| `database.enabled` | bool | Toggle installation |
| `database.chocoPackage` | string | Primary Chocolatey package name |
| `database.fallbackPackage` | string | Fallback Chocolatey package if primary fails |
| `database.verifyCommand` | string | Command to verify installation |
| `database.versionFlag` | string | Flag to check version |

## Install Path Options

1. **Dev directory** (default): `E:\dev-tool\redis`
2. **Custom path**: User-specified location
3. **System default**: Package manager default (e.g., `C:\Program Files`)

## Fallback Chain

Redis installation uses a fallback chain to handle the common MSI 1603 error
with the Memurai dependency in the `redis-64` package:

1. **Primary**: `redis-64` (Memurai-based, preferred)
2. **Fallback**: `redis` (tporadowski Windows port)
3. **Manual**: Logs a download URL if both packages fail

The chain is automatic -- if the primary package fails, the installer
immediately retries with the fallback package before reporting failure.

## Flow

1. Assert admin privileges
2. Resolve dev directory from config
3. Prompt for install location
4. Check if Redis is already installed
5. Install via Chocolatey (primary package)
6. If primary fails, retry with fallback package
7. If both fail, log manual download hint
8. Verify installation and save resolved state

## Install Keywords

| Keyword |
|---------|
| `redis` |
| `cache` |
| `key-value` |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `data-dev` | 20, 24, 28, 32 |
| `datadev` | 20, 24, 28, 32 |

```powershell
.\run.ps1 install redis
.\run.ps1 install data-dev
```
