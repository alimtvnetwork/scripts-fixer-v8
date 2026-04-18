# Spec: Centralised JSON Logging System

## Overview

All scripts produce structured JSON log files in a single `.logs/`
directory at the project root. Every `Write-Log` call during execution is
captured as a timestamped event. At script completion, events are flushed
to disk as JSON.

---

## Directory Layout

```
project-root/
├── .logs/                          # Gitignored -- never committed
│   ├── install-vscode.json         # Normal log for script 01
│   ├── install-golang.json         # Normal log for script 06
│   ├── install-golang-error.json   # Error log (only when errors occur)
│   ├── install-all-dev-tools.json  # Orchestrator log for script 12
│   └── ...
├── scripts/
│   └── shared/
│       └── logging.ps1
└── ...
```

The `.logs/` folder is auto-created by `Initialize-Logging` if it does not
exist. It should be covered by `.gitignore`.

---

## Functions

All functions live in `scripts/shared/logging.ps1`.

| Function | Purpose |
|----------|---------|
| `Initialize-Logging` | Starts event collection for a script run |
| `Write-Log` | Prints a badged console message AND records a structured event |
| `Save-LogFile` | Flushes collected events to JSON files on disk |
| `Write-Banner` | Displays a titled banner block (no log recording) |
| `Import-JsonConfig` | Loads a JSON file with verbose logging |

---

## Usage

Every `run.ps1` follows this pattern:

```powershell
# Every run.ps1 uses this crash-safe pattern (v0.4.1+)
Write-Banner -Title $logMessages.scriptName
Initialize-Logging -ScriptName $logMessages.scriptName

try {
    # ... script logic with Write-Log calls ...
}
catch {
    Write-Log "Script failed: $_" -Level "error"
    Write-Log $_.ScriptStackTrace -Level "error"
}
finally {
    $hasAnyErrors = $script:_LogErrors.Count -gt 0
    Save-LogFile -Status $(if ($hasAnyErrors) { "fail" } else { "ok" })
}
```

The `try/catch/finally` wrapper guarantees that `Save-LogFile` runs even
when an unhandled exception crashes the script. The `catch` block captures
the exception message and full stack trace as error-level events. The
`finally` block determines status dynamically from the error list.

### Dynamic Status

Scripts with success/failure tracking pass the status dynamically:

```powershell
Save-LogFile -Status $(if ($isSuccess) { "ok" } else { "fail" })
```

---

## File Name Convention

The `-ScriptName` parameter is sanitised to produce the filename:

| Script Name | Log File | Error File |
|-------------|----------|------------|
| `Install Golang` | `install-golang.json` | `install-golang-error.json` |
| `Install VS Code` | `install-vs-code.json` | `install-vs-code-error.json` |
| `Install All Dev Tools` | `install-all-dev-tools.json` | `install-all-dev-tools-error.json` |

**Sanitisation rules:**
1. Convert to lowercase
2. Replace non-alphanumeric sequences with `-`
3. Trim leading/trailing hyphens

---

## JSON Schema

### Normal Log (`<name>.json`)

```json
{
  "scriptName": "install-golang",
  "status": "ok",
  "startTime": "2026-04-05T15:30:00.0000000+08:00",
  "endTime": "2026-04-05T15:31:12.0000000+08:00",
  "duration": 72.34,
  "eventCount": 14,
  "errorCount": 0,
  "events": [
    {
      "timestamp": "2026-04-05T15:30:00.1234567+08:00",
      "level": "info",
      "message": "Checking for Chocolatey..."
    }
  ]
}
```

### Error Log (`<name>-error.json`)

```json
{
  "scriptName": "install-golang",
  "overallStatus": "fail",
  "startTime": "2026-04-05T15:30:00.0000000+08:00",
  "endTime": "2026-04-05T15:31:12.0000000+08:00",
  "duration": 72.34,
  "errorCount": 1,
  "warnCount": 2,
  "errors": [
    {
      "timestamp": "2026-04-05T15:30:45.6789012+08:00",
      "level": "fail",
      "message": "Failed to install 'golang': exit code 1"
    }
  ],
  "warnings": [
    {
      "timestamp": "2026-04-05T15:30:30.1234567+08:00",
      "level": "warn",
      "message": "Chocolatey shim not found: C:\\ProgramData\\chocolatey\\bin\\go.exe"
    },
    {
      "timestamp": "2026-04-05T15:30:31.2345678+08:00",
      "level": "warn",
      "message": "Get-Command could not find 'go' in PATH"
    }
  ]
}
```

---

## Error File Creation Rules

An error log file (`<name>-error.json`) is created when **either** condition
is true:

| Condition | Description |
|-----------|-------------|
| Any `fail`-level event | At least one `Write-Log -Level "error"` call was made during execution |
| Any `warn`-level event | At least one `Write-Log -Level "warn"` call was made during execution |
| Overall status is `"fail"` | `Save-LogFile -Status "fail"` was called (script-level failure) |

If none of these conditions are met, no error file is created.

---

## Version Highlighting

`Write-Log` automatically detects version numbers in messages (e.g. `v2.7.1`,
`2.53.0.windows.2`) and renders them in **Yellow** in the terminal for
visibility.

---

## Event Levels

| Level | Badge | Colour | Description |
|-------|-------|--------|-------------|
| `ok` | `[  OK  ]` | Green | Success |
| `fail` | `[ FAIL ]` | Red | Error (recorded in error log) |
| `info` | `[ INFO ]` | Cyan | Informational |
| `warn` | `[ WARN ]` | Yellow | Warning (recorded in error log) |
| `skip` | `[ SKIP ]` | DarkGray | Skipped step |

The `-Level` parameter accepts aliases: `success` maps to `ok`, `error` maps
to `fail`.

---

## Module-Scoped State

| Variable | Type | Purpose |
|----------|------|---------|
| `$script:_LogEvents` | `ArrayList` | All recorded events |
| `$script:_LogErrors` | `ArrayList` | Error and warning-level events (written to error log) |
| `$script:_LogName` | `string` | Sanitised script name (used as filename) |
| `$script:_LogStart` | `DateTime` | Timestamp when `Initialize-Logging` was called |
| `$script:_LogsDir` | `string` | Resolved path to `.logs/` at project root |

These are reset on each `Initialize-Logging` call.

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Root-level `.logs/` directory | Single location outside `scripts/`; easy to find, browse, and clean |
| JSON format (not transcript) | Structured, parseable, can be consumed by other tools |
| Separate error files | Quick scan for failures without parsing full event logs |
| Dual error-file trigger | Catches both individual error/warn events and overall script failure |
| No logging for early exits | Help, disabled-check, and admin-check exits happen before `Initialize-Logging` |
| Overwrite on re-run | Each run overwrites the previous log; logs are ephemeral diagnostics |
| `$script:` scope | Avoids global pollution; each dot-sourced script gets its own event buffer |
| Crash-safe finally block | `Save-LogFile` in `finally` guarantees log output even on unhandled exceptions |
| Warn events in error log | Warnings often indicate detection fallback paths that are diagnostic for failures |
