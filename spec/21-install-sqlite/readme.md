# Spec: Script 21 -- Install SQLite

## Purpose

Installs **SQLite CLI** and **DB Browser for SQLite** (GUI) with flexible
installation path options. Both are installed via Chocolatey.

---

## Usage

### From script folder (scripts/21-install-sqlite/)

```powershell
.\run.ps1          # Install SQLite CLI + DB Browser for SQLite
.\run.ps1 -Help    # Show usage
```

### From root dispatcher (project root)

```powershell
.\run.ps1 install sqlite       # Bare command
.\run.ps1 -Install sqlite      # Named parameter
```

### Via interactive database menu (script 30)

```powershell
.\run.ps1 install databases    # Select "4. SQLite" from the menu
```

---

## What Gets Installed

| # | Component | Choco Package | Purpose |
|---|-----------|---------------|---------|
| 1 | **SQLite CLI** | `sqlite` | Command-line interface for SQLite databases |
| 2 | **DB Browser for SQLite** | `sqlitebrowser` | GUI tool for browsing and editing SQLite databases |

Both components are toggled independently via `config.json`:
- `database.enabled` controls the SQLite CLI
- `database.browser.enabled` controls DB Browser for SQLite

---

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `devDir.mode` | string | Resolution mode (`json-or-prompt`) |
| `devDir.default` | string | Default dev directory path |
| `devDir.override` | string | Hard override (skips prompt) |
| `installMode.default` | string | Default install location (`devDir` / `custom` / `system`) |
| `database.enabled` | bool | Toggle SQLite CLI installation |
| `database.chocoPackage` | string | Chocolatey package for SQLite CLI (`sqlite`) |
| `database.verifyCommand` | string | Command to verify installation (`sqlite3`) |
| `database.versionFlag` | string | Flag to check version (`--version`) |
| `database.name` | string | Display name |
| `database.desc` | string | Short description |
| `database.type` | string | Category (`file-based`) |
| `database.browser.enabled` | bool | Toggle DB Browser for SQLite installation |
| `database.browser.name` | string | Friendly browser name (`DB Browser for SQLite`) |
| `database.browser.chocoPackage` | string | Chocolatey package (`sqlitebrowser`) |

---

## Install Path Options

1. **Dev directory** (default): `E:\dev-tool\sqlite`
2. **Custom path**: User-specified location
3. **System default**: Package manager default (e.g. `C:\Program Files`)

If the configured drive is unavailable or invalid, the shared dev-dir helper
falls back to a safe path such as `C:\dev-tool`.

---

## Execution Flow

```
run.ps1
  |
  +-- Assert admin privileges
  +-- Load config.json + log-messages.json
  +-- Resolve dev directory (with safe drive fallback)
  +-- Prompt for install location (dev dir / custom / system)
  |
  +-- SQLite CLI
  |     +-- Check if sqlite3 is already in PATH
  |     +-- If found: log version, save resolved state
  |     +-- If not found:
  |           +-- Install via Chocolatey (sqlite)
  |           +-- Refresh PATH
  |           +-- Verify sqlite3 is available
  |           +-- Save resolved state
  |
  +-- DB Browser for SQLite
  |     +-- Skip if browser.enabled is false
  |     +-- Install via Chocolatey (sqlitebrowser)
  |     +-- Log success or failure
  |
  +-- Show summary
```

---

## Helper Functions (helpers/sqlite.ps1)

| Function | Purpose |
|----------|---------|
| `Get-SqliteVersion` | Runs `sqlite3 --version` and returns the version string |
| `Save-SqliteResolvedState` | Writes version + timestamp to `.resolved/21-install-sqlite/` |
| `Install-SqliteBrowser` | Installs DB Browser for SQLite via Chocolatey if enabled |
| `Install-Sqlite` | Main orchestrator: installs CLI, verifies, then installs browser |

---

## Resolved State

On successful install, the script saves to `.resolved/21-install-sqlite/resolved.json`:

```json
{
  "version": "3.46.0 2024-05-23 ...",
  "resolvedAt": "2025-07-06T10:30:00.0000000+00:00",
  "resolvedBy": "USERNAME"
}
```

## Install Keywords

| Keyword |
|---------|
| `sqlite` |

```powershell
.\run.ps1 install sqlite
```
