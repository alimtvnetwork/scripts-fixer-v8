# Spec: Invoke-WithTimeout (Shared Helper)

## Overview

A shared PowerShell function that wraps any operation in a **timeout guard**.
If the operation exceeds the allowed time, it is forcefully terminated, and
a detailed log entry is written explaining what was running and how long it
was stuck.

---

## Problem

Some PowerShell operations -- particularly registry writes, CLI calls, and
file system operations -- can hang indefinitely with no visible error. The
script appears frozen, and there is no log output to explain why.

## Solution

A reusable `Invoke-WithTimeout` function that:

- Accepts a **script block** and a **timeout in seconds**
- Runs the script block in a background **job**
- Polls the job with a configurable interval
- Logs elapsed time at each poll interval
- If the timeout is exceeded:
  - Kills the job
  - Logs the operation name, timeout value, and elapsed time
  - Returns a failure result
- If the job completes within the limit:
  - Logs the elapsed time
  - Returns the job output

---

## File Location

```
scripts/
└── shared/
    ├── git-pull.ps1         # Existing shared helper
    └── invoke-with-timeout.ps1   # This helper
```

## Function Signature

```powershell
Invoke-WithTimeout
    -Label        <string>       # Human-readable name for the operation (used in logs)
    -ScriptBlock  <scriptblock>  # The code to execute
    -TimeoutSecs  <int>          # Maximum allowed seconds (default: 120)
    -PollSecs     <int>          # How often to check status (default: 5)
```

## Return Value

Returns a hashtable:

```powershell
@{
    Success  = $true / $false
    Output   = <job output or $null>
    Elapsed  = <total seconds>
    TimedOut = $true / $false
}
```

## Logging Behavior

### During execution (at each poll interval):

```
  [ WAIT ] [Register-ContextMenu] Running... 5s / 120s
  [ WAIT ] [Register-ContextMenu] Running... 10s / 120s
```

### On success:

```
  [  OK  ] [Register-ContextMenu] Completed in 2.3s
```

### On timeout:

```
  [ FAIL ] [Register-ContextMenu] TIMED OUT after 120s (limit: 120s)
  [ FAIL ] [Register-ContextMenu] The operation was forcefully terminated
  [ INFO ] [Register-ContextMenu] Possible causes: interactive prompt, locked resource, network hang
```

## How Child Scripts Use It

```powershell
# Dot-source the helper
$timeoutHelper = Join-Path $ScriptDir "..\shared\invoke-with-timeout.ps1"
. $timeoutHelper

# Wrap a potentially-hanging operation
$result = Invoke-WithTimeout `
    -Label "Registry key creation" `
    -TimeoutSecs 30 `
    -ScriptBlock {
        New-Item -Path "HKCR:\*\shell\VSCode" -Force -ErrorAction Stop
    }

if (-not $result.Success) {
    Write-Log "Operation failed or timed out" "fail"
}
```

## Recommended Timeout Values

| Operation Type | Timeout | Rationale |
|----------------|---------|-----------|
| Registry key creation | 30s | Should be instant; 30s is generous |
| Registry value set | 30s | Same as above |
| File copy / backup | 30s | Local disk I/O |
| Extension install (single) | 120s | Network download + install |
| Full context menu script | 120s | Total for all registry operations |
| Full settings sync script | 300s | Many extensions to install |
| Git pull | 60s | Network operation |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Background job approach | PowerShell has no native statement timeout; jobs can be killed |
| Polling with log output | User sees progress and knows it is not frozen |
| Label parameter | Logs are readable without knowing internal details |
| Returns hashtable | Caller decides how to handle timeout vs error vs success |
| Default 120s timeout | Context menu fixes should never take more than 2 minutes |
| Graceful kill | `Stop-Job` then `Remove-Job` to clean up resources |
| Possible-causes hint | Helps user (and AI) debug without re-reading source |

## Naming Conventions

| Rule | Example |
|------|---------|
| File name: lowercase-hyphenated | `invoke-with-timeout.ps1` |
| Function name: Verb-Noun PascalCase | `Invoke-WithTimeout` |

## Integration Plan

1. Create `scripts/shared/invoke-with-timeout.ps1`
2. Update script 01 (`Register-ContextMenu`) to wrap registry operations
3. Update script 02 (`Install-Extensions`) to wrap CLI calls
4. Update `git-pull.ps1` to use timeout for `git pull`
5. Update all specs to document the timeout mechanism
