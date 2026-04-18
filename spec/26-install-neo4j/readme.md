# Spec: Script 26 -- Install Neo4j

## Purpose

Installs Neo4j with flexible installation path options.
Graph database for connected data.

## Usage

```powershell
.\run.ps1          # Install Neo4j (interactive path prompt)
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

1. **Dev directory** (default): `E:\dev-tool\neo4j`
2. **Custom path**: User-specified location
3. **System default**: Package manager default (e.g., `C:\Program Files`)

## Flow

1. Assert admin privileges
2. Resolve dev directory from config
3. Prompt for install location
4. Check if Neo4j is already installed
5. Install via Chocolatey if not found
6. Verify installation and save resolved state

## Install Keywords

| Keyword |
|---------|
| `neo4j` |

```powershell
.\run.ps1 install neo4j
```
