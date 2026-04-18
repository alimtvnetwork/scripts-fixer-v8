# Spec: Script 20 -- Install PostgreSQL

## Purpose

Installs PostgreSQL with flexible installation path options.
Advanced open-source relational database.

## Usage

```powershell
.\run.ps1          # Install PostgreSQL (interactive path prompt)
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
| `database.chocoPackage` | string | Chocolatey package name |
| `database.verifyCommand` | string | Command to verify installation |
| `database.versionFlag` | string | Flag to check version |

## Install Path Options

1. **Dev directory** (default): `E:\dev-tool\postgresql`
2. **Custom path**: User-specified location
3. **System default**: Package manager default (e.g., `C:\Program Files`)

## Flow

1. Assert admin privileges
2. Resolve dev directory from config
3. Prompt for install location
4. Check if PostgreSQL is already installed
5. Install via Chocolatey if not found
6. Verify installation and save resolved state

## Install Keywords

| Keyword |
|---------|
| `postgresql` |
| `postgres` |
| `psql` |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `backend` | 5, 6, 16, 20 |
| `data-dev` | 20, 24, 28, 32 |
| `datadev` | 20, 24, 28, 32 |

```powershell
.\run.ps1 install postgresql
.\run.ps1 install backend
```
