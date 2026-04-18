# Spec: Doctor Command

## Purpose

Quick health-check that verifies the project setup itself. Lighter than
full audit -- runs in < 2 seconds for quick sanity checks.

## Usage

```powershell
.\run.ps1 doctor
```

## Checks Performed

| # | Check | Pass | Fail | Warn |
|---|-------|------|------|------|
| 1 | Scripts directory exists | Found | Not found | -- |
| 2 | version.json is valid | Parsed, version present | Parse error or empty | -- |
| 3 | registry.json is valid | Parsed, count shown | Parse error | -- |
| 4 | Registry folders exist | All folders present | Missing folders listed | -- |
| 5 | .logs/ directory exists | Found + file count | -- | Created on first run |
| 6 | .installed/ directory exists | Found + tool count | -- | No tools tracked yet |
| 7 | Chocolatey is reachable | Found + version | Not in PATH | -- |
| 8 | Running as Administrator | Yes | -- | Some scripts require admin |
| 9 | Shared helpers present | All 9 found | Missing listed | -- |
| 10 | install-keywords.json valid | Parsed + keyword count | Parse error | -- |

## Output Format

```
  Project Doctor
  ==============

    [PASS] Scripts directory exists -- D:\project\scripts
    [PASS] version.json is valid -- v0.17.1
    [PASS] registry.json is valid -- 41 scripts registered
    [PASS] Registry folders exist -- All 41 folders present
    [PASS] .logs/ directory exists -- 5 log file(s)
    [PASS] .installed/ directory exists -- 8 tool(s) tracked
    [PASS] Chocolatey is reachable -- v2.6.0
    [WARN] Running as Administrator -- Some scripts require admin rights
    [PASS] Shared helpers present -- 9 helpers found
    [PASS] install-keywords.json is valid -- 154 keywords mapped

  Summary: 9 passed, 1 warning(s)

  Project looks good with minor warnings.
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| No admin required | Doctor itself just reads files |
| No Chocolatey operations | Fast execution, no network |
| Color-coded output | Instant visual scan |
| Summary line | Quick pass/fail count |
