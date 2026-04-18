# Spec: symlink-utils.ps1

## Overview

Shared helper for creating **directory junctions** (symlinks) from the dev
directory to actual database install locations. After Chocolatey installs a
database to its default system path, this module creates a junction so all
databases appear organized under `<devDir>\databases\`.

**File:** `scripts/shared/symlink-utils.ps1`
**Added in:** v0.5.0

---

## Functions

### Resolve-DbInstallDir

Resolves the actual install directory for a database by locating its
executable via `Get-Command` and walking up the directory tree to the
install root.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-VerifyCommand` | string | Yes | The CLI command used to verify the database (e.g. `mysql`, `psql`, `mongod`) |

#### Returns

- The resolved install directory path (string), or `$null` if the command
  is not found.

#### Directory Resolution Logic

The function finds the executable path via `Get-Command`, then determines the
install root based on the parent directory name:

| Parent dir name | Resolution | Example |
|-----------------|------------|---------|
| `bin` | One level up from `bin` | `...\MySQL Server 8.0\bin\mysql.exe` -> `...\MySQL Server 8.0` |
| `tools` | One level up from `tools` (Chocolatey pattern) | `...\chocolatey\lib\duckdb\tools\duckdb.exe` -> `...\chocolatey\lib\duckdb` |
| (anything else) | The directory containing the exe | `...\Redis\redis-server.exe` -> `...\Redis` |

#### Known Patterns

```
MySQL:         C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe         -> C:\Program Files\MySQL\MySQL Server 8.0
PostgreSQL:    C:\Program Files\PostgreSQL\16\bin\psql.exe                    -> C:\Program Files\PostgreSQL\16
MongoDB:       C:\Program Files\MongoDB\Server\7.0\bin\mongod.exe            -> C:\Program Files\MongoDB\Server\7.0
DuckDB:        C:\ProgramData\chocolatey\lib\duckdb\tools\duckdb.exe         -> C:\ProgramData\chocolatey\lib\duckdb
Redis:         C:\Program Files\Redis\redis-server.exe                       -> C:\Program Files\Redis
SQLite:        C:\ProgramData\chocolatey\lib\SQLite\tools\sqlite3.exe        -> C:\ProgramData\chocolatey\lib\SQLite
```

---

### New-DbSymlink

Creates a directory junction from `<DevDir>\databases\<Name>` to the actual
install location of a database.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Name` | string | Yes | Database identifier (typically the Chocolatey package name, e.g. `mysql`, `postgresql`) |
| `-VerifyCommand` | string | Yes | CLI command to locate the install (e.g. `mysql`, `psql`) |
| `-DevDir` | string | Yes | The resolved dev directory path (e.g. `E:\dev-tool`) |

#### Returns

- `$true` if the junction was created successfully or already points to the correct target.
- `$false` on failure (source not found, real directory exists, or junction creation error).

#### Execution Flow

1. Call `Resolve-DbInstallDir` to find the actual install path
2. If source not found or doesn't exist: log warning, return `$false`
3. Create `<DevDir>\databases\` parent directory if missing
4. Check if junction already exists at `<DevDir>\databases\<Name>`:
   - **Junction with correct target:** skip, return `$true`
   - **Junction with wrong target (stale):** remove and recreate
   - **Real directory (not a junction):** skip with warning, return `$false`
5. Create the junction via `New-Item -ItemType Junction`
6. Log success/failure

#### Result Structure

After running all database installers, the dev directory will contain:

```
E:\dev-tool\
  databases\
    mysql\          -> C:\Program Files\MySQL\MySQL Server 8.0  (junction)
    postgresql\     -> C:\Program Files\PostgreSQL\16            (junction)
    mongodb\        -> C:\Program Files\MongoDB\Server\7.0      (junction)
    redis\          -> C:\Program Files\Redis                    (junction)
    duckdb\         -> C:\ProgramData\chocolatey\lib\duckdb     (junction)
    ...
```

---

## Edge Cases

| Condition | Behaviour |
|-----------|-----------|
| Verify command not found in PATH | `Resolve-DbInstallDir` returns `$null`; symlink skipped with warning |
| Actual install dir doesn't exist on disk | Symlink skipped with warning |
| Junction already exists with correct target | Skipped (idempotent), returns `$true` |
| Stale junction (points to old/wrong path) | Removed and recreated |
| Real directory exists at junction path | Skipped with warning (won't overwrite user data) |
| Junction creation fails (permissions, etc.) | Error logged, returns `$false` |
| Database installed via dotnet tool (LiteDB) | `Get-Command` resolves from `~\.dotnet\tools` |

---

## Log Messages

All messages are defined in `scripts/shared/log-messages.json`:

| Key | Level | Message |
|-----|-------|---------|
| `symlinkSourceNotFound` | warn | Could not resolve install directory for {name} |
| `symlinkParentCreated` | info | Created databases directory: {path} |
| `symlinkAlreadyCorrect` | info | Symlink for {name} already correct: {path} |
| `symlinkRemovedStale` | warn | Removed stale symlink for {name} |
| `symlinkRealDirExists` | warn | Real directory already exists at {path} for {name} |
| `symlinkCreated` | success | Symlink created: {link} -> {target} ({name}) |
| `symlinkFailed` | error | Failed to create symlink for {name}: {error} |

---

## Usage

Called automatically by each database `run.ps1` after successful install:

```powershell
# In scripts/18-install-mysql/run.ps1 (and all other DB scripts)
. (Join-Path $sharedDir "symlink-utils.ps1")

$ok = Install-Mysql -DbConfig $config.database -LogMessages $logMessages

if ($ok) {
    New-DbSymlink -Name ($config.database.chocoPackage) `
                  -VerifyCommand ($config.database.verifyCommand) `
                  -DevDir $devDir
}
```

Can also be called standalone:

```powershell
. .\scripts\shared\symlink-utils.ps1

# Resolve where MySQL is actually installed
$mysqlDir = Resolve-DbInstallDir -VerifyCommand "mysql"
# Returns: C:\Program Files\MySQL\MySQL Server 8.0

# Create junction
New-DbSymlink -Name "mysql" -VerifyCommand "mysql" -DevDir "E:\dev-tool"
# Creates: E:\dev-tool\databases\mysql -> C:\Program Files\MySQL\MySQL Server 8.0
```

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Directory junctions (not symbolic links) | Junctions work without elevated privileges on NTFS and are transparent to all applications |
| Resolve from `Get-Command` (not hardcoded paths) | Handles different Chocolatey versions, custom install paths, and non-standard layouts |
| Walk up from `bin/` or `tools/` | Covers both standard installers (`bin\exe`) and Chocolatey shim packages (`tools\exe`) |
| Idempotent (skip if correct) | Safe to re-run; won't break existing junctions |
| Never overwrite real directories | Protects user data if they manually created the folder |
| Stale junction auto-cleanup | Handles upgrades that change the install path (e.g. PostgreSQL 15 -> 16) |
