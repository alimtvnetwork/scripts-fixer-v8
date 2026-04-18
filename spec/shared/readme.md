# Spec: Shared Helpers

## Overview

Shared PowerShell modules that live in `scripts/shared/` and are dot-sourced
by individual scripts. This avoids duplicating common logic across scripts.

---

## File Structure

```
scripts/
├── logs/                  # Centralised JSON logs (gitignored, never committed)
│   ├── golang.json        # Structured event log for script 06
│   ├── golang-error.json  # Error-only log (created when errors occur)
│   └── ...
└── shared/
    ├── logging.ps1       # Write-Log, Write-Banner, Initialize-Logging, Save-LogFile, Import-JsonConfig
    ├── log-messages.json  # Shared log message strings (choco, cleanup, path, etc.)
    ├── git-pull.ps1      # Invoke-GitPull
    ├── resolved.ps1      # Save-ResolvedData, Get-ResolvedDir
    ├── cleanup.ps1       # Clear-ResolvedData
    ├── help.ps1          # Show-ScriptHelp
    ├── choco-utils.ps1   # Assert-Choco, Install-ChocoPackage, Upgrade-ChocoPackage
    ├── path-utils.ps1    # Test-InPath, Add-ToUserPath, Add-ToMachinePath
    ├── dev-dir.ps1       # Resolve-DevDir, Resolve-SmartDevDir, Find-BestDevDrive, Test-DriveQualified, Initialize-DevDir
    ├── symlink-utils.ps1        # Resolve-DbInstallDir, New-DbSymlink
    ├── json-utils.ps1           # Backup-File, Merge-JsonDeep, ConvertTo-OrderedHashtable
    ├── invoke-with-timeout.ps1  # Invoke-WithTimeout
    ├── download-retry.ps1       # Invoke-DownloadWithRetry (3 retries, exponential backoff)
    ├── disk-space.ps1           # Test-DiskSpace, Get-TotalDownloadSize
    ├── url-freshness.ps1        # Test-UrlFreshness (HEAD-check download URLs)
    ├── aria2c-download.ps1      # Assert-Aria2c, Invoke-Aria2Download (multi-connection via aria2c + fallback)
    └── hardware-detect.ps1      # Test-CudaAvailable, Test-Avx2Available, Get-HardwareProfile, Test-ExecutableCompatible

.resolved/                # Runtime-resolved data (gitignored, never committed)
├── 01-vscode-context-menu-fix/
│   └── resolved.json
└── 02-vscode-settings-sync/
    └── resolved.json
```

---

## Conventions

### Bootstrap Block

Every shared helper (and every `helpers/*.ps1` file) includes a **bootstrap
block** at the top that ensures `Write-Log` and `$script:SharedLogMessages`
are available, even when the file is dot-sourced in isolation:

```powershell
# -- Bootstrap shared helpers --------------------------------------------------
$loggingPath = Join-Path $PSScriptRoot "logging.ps1"
if ((Test-Path $loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $loggingPath
}

if (-not (Get-Variable -Name SharedLogMessages -Scope Script -ErrorAction SilentlyContinue)) {
    $sharedLogPath = Join-Path $PSScriptRoot "log-messages.json"
    if (Test-Path $sharedLogPath) {
        $script:SharedLogMessages = Get-Content $sharedLogPath -Raw | ConvertFrom-Json
    }
}
```

For helpers inside `scripts/NN-xxx/helpers/`, the path calculation differs
(two levels up to reach `shared/`):

```powershell
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
```

### Strict-Mode Safety

All `run.ps1` files use `Set-StrictMode -Version Latest`. Under strict mode,
accessing an unset `$script:` variable throws an error. Therefore:

- **Never** use `$null -eq $script:SomeVar` to test for existence.
- **Always** use `Get-Variable -Name SomeVar -Scope Script -ErrorAction SilentlyContinue`.

### Log Messages

- **No hardcoded strings in `Write-Log` calls.** Every message comes from
  either `$logMessages.messages.*` (per-script) or `$slm.messages.*` (shared).
- Shared helpers read from `scripts/shared/log-messages.json` via
  `$script:SharedLogMessages` (aliased to `$slm` inside functions).
- Per-script messages live in `scripts/NN-xxx/log-messages.json` and are
  loaded via `Import-JsonConfig` at the top of each `run.ps1`.
- Placeholders use `{name}` syntax and are replaced with `-replace '\{name\}', $value`.

### Boolean Variables

- Use `$is` / `$has` prefixes for boolean variables.
- Avoid bare `-not` in `if` conditions -- assign to a named boolean first.

```powershell
# Good
$isDirMissing = -not (Test-Path $dir)
if ($isDirMissing) { ... }

# Avoid
if (-not (Test-Path $dir)) { ... }
```

### Naming

| Rule | Example |
|------|---------|
| File names: lowercase-hyphenated (kebab-case) | `git-pull.ps1` |
| Folder names: lowercase-hyphenated | `shared` |
| PowerShell functions: Verb-Noun PascalCase | `Invoke-GitPull` |

---

## logging.ps1

### Functions

| Function | Purpose |
|----------|---------|
| `Write-Log` | Prints a status-badged message (`[  OK  ]`, `[ FAIL ]`, etc.) and records a structured event |
| `Write-Banner` | Displays a titled banner block with border lines |
| `Initialize-Logging` | Initialises the JSON log collector for a script (sets script name, creates `scripts/logs/` if needed) |
| `Save-LogFile` | Flushes collected events to `scripts/logs/<name>.json` and `<name>-error.json` if errors exist |
| `Import-JsonConfig` | Loads and returns a JSON file with verbose logging |

### Write-Log

Accepts `-Status` (old-style: `ok`, `fail`, `info`, `warn`, `skip`) or
`-Level` (new-style: `success`, `error`, `info`, `warn`, `skip`). The
`-Level` param maps `success` -> `ok` and `error` -> `fail`.

Badge text comes from `$script:LogMessages.status.*` if set (per-script), with
hardcoded fallbacks (`[  OK  ]`, `[ FAIL ]`, etc.) when the status block is absent.

### Write-Banner

Supports two calling styles:

```powershell
# Old-style: explicit line array
Write-Banner @("---", "  Title", "---") "Magenta"

# New-style: -Title and -Version params (auto-generates border)
Write-Banner -Title "My Script" -Version "1.0.0"
```

### Import-JsonConfig

```powershell
$config = Import-JsonConfig (Join-Path $scriptDir "config.json")
$logMessages = Import-JsonConfig (Join-Path $scriptDir "log-messages.json")
```

Logs the file path, size, and success/failure using shared log messages.
Returns `$null` if the file is missing.

---

## log-messages.json

The shared log messages file contains strings used by all shared helpers.
Keys are grouped by helper:

| Prefix | Used by |
|--------|---------|
| `choco*` | `choco-utils.ps1` |
| `cleanup*` | `cleanup.ps1` |
| `devDir*` | `dev-dir.ps1` |
| `backup*` | `json-utils.ps1` |
| `import*` | `logging.ps1` (`Import-JsonConfig`) |
| `path*` | `path-utils.ps1` |
| `resolved*` | `resolved.ps1` |
| `gitPull*` | `git-pull.ps1` |
| `help*` | `help.ps1` |
| `adminTip` | `run.ps1` files (admin privilege error) |
| `timeout*` | `invoke-with-timeout.ps1` |
| `download*` | `download-retry.ps1` |
| `diskSpace*` | `disk-space.ps1` |

---

## git-pull.ps1

### Purpose

Provides `Invoke-GitPull` -- runs `git pull` from the repo root.

### Skip Mechanism

| Scenario | Behavior |
|----------|----------|
| Script run directly (`.\scripts\01-...\run.ps1`) | `$env:SCRIPTS_ROOT_RUN` is not set -- git pull runs |
| Script run via root dispatcher (`.\run.ps1 -I 1`) | Root sets `$env:SCRIPTS_ROOT_RUN = "1"` -- git pull is skipped |

### Function Signature

```powershell
Invoke-GitPull [-RepoRoot <string>]
```

Auto-detects the repo root from `$script:ScriptDir` if `-RepoRoot` is omitted.

---

## resolved.ps1

### Purpose

Persists **runtime-discovered state** to `.resolved/` at the repo root.

### Design Principle

**Config files are input. Resolved data is output.**

- `config.json` -- user-editable, declarative settings (committed to git)
- `.resolved/` -- runtime state: expanded paths, timestamps (gitignored)

### Functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| `Get-ResolvedDir` | `-ScriptDir <string>` | Returns `.resolved/<script-folder>/` path, creating it if needed |
| `Save-ResolvedData` | `-ScriptDir <string> -Data <hashtable>` or `-ScriptFolder <string> -Data <hashtable>` | Merges new keys into `resolved.json`, preserving existing data |

### Merge Semantics

If `resolved.json` already exists, existing keys are preserved and new keys
overlay on top. This allows multiple editions (or multiple runs) to coexist
in one file without overwriting each other.

### Cache-First Pattern (Script 01)

Script 01 checks `.resolved/` **before** running path detection:

```powershell
$resolvedFile = Join-Path (Get-ResolvedDir -ScriptDir $ScriptDir) "resolved.json"
if (Test-Path $resolvedFile) {
    $cached = Get-Content $resolvedFile -Raw | ConvertFrom-Json
    $cachedExe = $cached.$EditionName.resolvedExe
    if ($cachedExe -and (Test-Path $cachedExe)) {
        return $cachedExe   # Skip detection
    }
}
```

---

## cleanup.ps1

### Purpose

Provides `Clear-ResolvedData` to wipe cached runtime state.

### Function Signature

```powershell
Clear-ResolvedData -ScriptDir <string> [-EditionName <string>]
```

### Modes

| Call | Effect |
|------|--------|
| `Clear-ResolvedData -ScriptDir $ScriptDir` | Removes **all** contents of `.resolved/` |
| `Clear-ResolvedData -ScriptDir $ScriptDir -EditionName "stable"` | Removes only the `"stable"` key from that script's `resolved.json` |

---

## help.ps1

### Purpose

Provides `Show-ScriptHelp` for consistent `--help` output across all scripts.

### Function Signature

```powershell
# New-style (preferred): pass the entire log-messages object
Show-ScriptHelp -LogMessages $logMessages

# Old-style: explicit params
Show-ScriptHelp -Name "My Script" -Version "1.0.0" -Description "..." -Commands @(...) -Examples @(...)
```

The new-style call extracts `scriptName`, `version`, `description`,
`help.commands`, and `help.examples` from the log-messages JSON object.

### Expected log-messages.json Shape

```json
{
  "scriptName": "Install Foo",
  "version": "1.0.0",
  "description": "Installs Foo via Chocolatey.",
  "messages": { ... },
  "help": {
    "commands": { "all": "Install everything (default)" },
    "examples": [ ".\\run.ps1", ".\\run.ps1 -Help" ]
  }
}
```

---

## choco-utils.ps1

### Purpose

Chocolatey package management helpers. Requires administrator privileges.

### Functions

| Function | Purpose |
|----------|---------|
| `Assert-Choco` | Ensures Chocolatey is installed; installs it if missing. Returns `$true` if available. |
| `Install-ChocoPackage` | Installs a package if not already present. Accepts optional `-Version`. |
| `Upgrade-ChocoPackage` | Upgrades an existing package to the latest version. |

### Usage

```powershell
Assert-Choco
Install-ChocoPackage -PackageName "golang" -Version "1.22.0"
Upgrade-ChocoPackage -PackageName "golang"
```

---

## path-utils.ps1

### Purpose

Safe PATH manipulation with deduplication.

### Functions

| Function | Purpose |
|----------|---------|
| `Test-InPath` | Checks if a directory is in the specified PATH scope (`User`, `Machine`, `Process`) |
| `Add-ToUserPath` | Adds a directory to the user PATH if not already present |
| `Add-ToMachinePath` | Adds a directory to the machine PATH if not already present (requires admin) |

Both `Add-To*Path` functions also update `$env:Path` for the current session
after modifying the persistent environment variable.

---

## dev-dir.ps1

### Purpose

Resolves and initializes the base dev directory (e.g. `E:\dev-tool`).

### Functions

| Function | Purpose |
|----------|---------|
| `Resolve-DevDir` | Resolves the dev directory path from env var, config override, user prompt, or default |
| `Initialize-DevDir` | Creates the dev directory and optional subdirectories if missing |

### Resolution Priority

1. `$env:DEV_DIR` (set by the orchestrator, script 04)
2. Config `override` value (non-empty string in config)
3. User prompt (if mode is `json-or-prompt`)
4. Config `default` value (fallback: `E:\dev-tool`)

---

## json-utils.ps1

### Purpose

Common JSON and file utilities.

### Functions

| Function | Purpose |
|----------|---------|
| `Backup-File` | Creates a timestamped backup copy before overwriting a file |
| `ConvertTo-OrderedHashtable` | Converts a `PSCustomObject` to an ordered hashtable (for deep merge) |
| `Merge-JsonDeep` | Recursively deep-merges two hashtables; incoming keys overwrite, existing-only keys preserved |

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Dot-sourcing (not PS modules) | No module manifest overhead; simple function import |
| Environment variable flag for skip | Simple, no file I/O, works across process boundaries |
| Config is read-only at runtime | Scripts never mutate `config.json` -- keeps it declarative and git-friendly |
| `.resolved/` is gitignored | Runtime state (paths, timestamps) belongs outside version control |
| Merge semantics in `Save-ResolvedData` | Multiple editions can write to the same `resolved.json` without overwriting each other |
| Granular cleanup | `Clear-ResolvedData` supports per-edition clearing, not just full wipe |
| Cache-first detection | Avoids redundant filesystem probing on repeated runs |
| Bootstrap block in every file | Helpers work correctly whether dot-sourced from `run.ps1` or in isolation |
| `Get-Variable` for strict-mode checks | `$null -eq $script:Var` throws under `Set-StrictMode -Version Latest` |
| All log strings externalized to JSON | Enables future localization and keeps PS code free of display text |

---

## invoke-with-timeout.ps1

### Purpose

Wraps any operation in a background job with a configurable timeout guard.
If the operation exceeds the allowed time it is forcefully terminated and a
detailed log entry explains what was running and how long it was stuck.

### Function Signature

```powershell
Invoke-WithTimeout
    -Label        <string>       # Human-readable name for the operation (used in logs)
    -ScriptBlock  <scriptblock>  # The code to execute
    -TimeoutSecs  <int>          # Maximum allowed seconds (default: 120)
    -PollSecs     <int>          # How often to check status (default: 5)
```

### Return Value

```powershell
@{
    Success  = $true / $false
    Output   = <job output or $null>
    Elapsed  = <total seconds>
    TimedOut = $true / $false
}
```

### Logging Behaviour

| Phase | Example output |
|-------|----------------|
| Polling | `[ INFO ] [Register-ContextMenu] Running... 5s / 120s` |
| Success | `[  OK  ] [Register-ContextMenu] Completed in 2.3s` |
| Timeout | `[ FAIL ] [Register-ContextMenu] TIMED OUT after 120s (limit: 120s)` |
| Hint | `[ INFO ] [Register-ContextMenu] Possible causes: interactive prompt, locked resource, network hang` |

### Recommended Timeout Values

| Operation Type | Timeout | Rationale |
|----------------|---------|-----------|
| Registry key creation | 30s | Should be instant; 30s is generous |
| File copy / backup | 30s | Local disk I/O |
| Single choco package install | 120s | Network download + install |
| Full settings sync | 300s | Many extensions to install |
| Git pull | 60s | Network operation |

### Usage

```powershell
. (Join-Path $sharedDir "invoke-with-timeout.ps1")

$result = Invoke-WithTimeout `
    -Label "Install MinGW" `
    -TimeoutSecs 120 `
    -ScriptBlock {
        choco install mingw -y 2>&1
    }

$isTimedOut = $result.TimedOut
if ($isTimedOut) {
    Write-Log "MinGW install timed out" -Level "error"
}
```

---

## download-retry.ps1

### Purpose

Wraps `Invoke-WebRequest` with automatic retry and exponential backoff for
resilient large-file downloads.

### Function Signature

```powershell
Invoke-DownloadWithRetry
    -Uri          <string>   # URL to download from
    -OutFile      <string>   # Local file path
    -MaxRetries   <int>      # Max attempts (default: 3)
    -BaseDelaySec <int>      # Base backoff delay in seconds (default: 5)
    -Label        <string>   # Friendly name for log messages
```

### Return Value

Returns `$true` on success, `$false` after all retries exhausted.

### Behaviour

- Uses `Invoke-WebRequest -UseBasicParsing` with `SilentlyContinue` progress
- Validates downloaded file exists and is non-zero bytes
- Exponential backoff: delay doubles each retry (5s, 10s, 20s)
- Cleans up partial/empty files on final failure
- Logs attempt number, file size on success, and error details on failure

---

## disk-space.ps1

### Purpose

Pre-checks available disk space before starting large downloads. Prevents
wasted bandwidth on drives with insufficient free space.

### Functions

| Function | Purpose |
|----------|---------|
| `Test-DiskSpace` | Checks if a target drive has enough free space; returns `$true`/`$false` |
| `Get-TotalDownloadSize` | Sums expected download sizes from config arrays (supports `expectedSizeBytes` and `sizeHint` parsing) |

### Test-DiskSpace Signature

```powershell
Test-DiskSpace
    -TargetPath     <string>   # Directory where files will be written
    -RequiredBytes  <long>     # Minimum free bytes needed
    -RequiredGB     <double>   # Alternative: minimum free GB needed
    -Label          <string>   # Friendly name for log messages
    -WarnOnly       <switch>   # If set, warns but returns $true (non-blocking)
```

### Behaviour

| Mode | Insufficient Space | Return |
|------|-------------------|--------|
| Default (blocking) | Logs error with exact shortfall | `$false` |
| `-WarnOnly` | Logs warning with shortfall | `$true` |
| Drive undetectable | Logs warning, proceeds | `$true` |

### Get-TotalDownloadSize

Parses size information from config arrays:
- Exact: reads `expectedSizeBytes` field directly
- Hint: parses `sizeHint` strings like `"~5 GB"` or `"~4.7 GB"`

### Usage

```powershell
. (Join-Path $sharedDir "disk-space.ps1")

# Blocking check with exact bytes
$totalBytes = Get-TotalDownloadSize -Items $config.executables -SizeBytesField "expectedSizeBytes"
$isDiskOk = Test-DiskSpace -TargetPath $baseDir -RequiredBytes $totalBytes -Label "executables"
if (-not $isDiskOk) { return }

# Warning-only check with GB
Test-DiskSpace -TargetPath $modelsDir -RequiredGB 40 -Label "GGUF models" -WarnOnly
```

---

## hardware-detect.ps1

### Purpose

Detects CUDA GPU and AVX2 CPU capabilities so scripts can skip incompatible
binary variants instead of downloading files that won't run.

### Functions

| Function                  | Purpose                                                      |
|---------------------------|--------------------------------------------------------------|
| `Test-CudaAvailable`     | Checks for NVIDIA CUDA GPU via nvidia-smi, nvcc, or WMI     |
| `Test-Avx2Available`     | Checks for AVX2 CPU support via WMI + generation heuristic  |
| `Get-HardwareProfile`    | Returns combined CUDA + AVX2 results with logging            |
| `Test-ExecutableCompatible` | Checks if a `requires` value matches the hardware profile |

### Test-CudaAvailable Detection Chain

1. `nvidia-smi.exe --query-gpu=name,driver_version` -- most reliable
2. `nvcc.exe` in PATH -- CUDA toolkit installed
3. `Win32_VideoController` WMI -- any NVIDIA GPU present
4. CUDA version extracted from `nvidia-smi` full output

Returns `@{ Available; Version; Driver; GpuName }`.

### Test-Avx2Available Detection Chain

1. `Win32_Processor` WMI -- get CPU name
2. Heuristic: Intel Core i3/5/7/9, Xeon, Core Ultra, AMD Ryzen/EPYC/Threadripper = AVX2
3. Fallback: assume AVX2 on 64-bit Windows (conservative default)

Returns `@{ Available; CpuName }`.

### Config Integration

Each executable variant in `config.json` has a `requires` field:

| Value   | Meaning                                |
|---------|----------------------------------------|
| `"cuda"` | Requires NVIDIA CUDA GPU              |
| `"avx2"` | Requires AVX2 CPU instructions        |
| `""`     | No hardware requirement (always install) |

### Usage

```powershell
. (Join-Path $sharedDir "hardware-detect.ps1")

$hwProfile = Get-HardwareProfile

foreach ($item in $config.executables) {
    $isCompatible = Test-ExecutableCompatible -Requires $item.requires -HardwareProfile $hwProfile
    if (-not $isCompatible) {
        Write-Log "Skipping $($item.slug): requires $($item.requires)" -Level "info"
        continue
    }
    # proceed with download...
}
```
