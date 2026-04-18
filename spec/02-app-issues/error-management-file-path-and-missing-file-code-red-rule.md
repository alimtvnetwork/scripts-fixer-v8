# Spec: Error Management -- File Path and Missing File (Code Red Rule)

## Overview

Every file-related or path-related error log **must** include the exact file path
and the reason why the operation failed. This is a **code-red priority** rule --
no exceptions.

---

## The Rule

1. Every file-related error log must include the **exact file path** that was attempted.
2. Every path-related error log must include the **exact resolved path** that failed.
3. Every missing-file error must include the **reason** why the file was not found.
4. Generic "file not found" messages without exact paths are **forbidden**.

---

## Mandatory Logging Fields

| Field | Required | Description |
|-------|----------|-------------|
| Error level | Yes | `fail` (code red) or `warn` where applicable |
| Exact file path | Yes | The full resolved path that was attempted |
| Operation | Yes | `read`, `write`, `copy`, `move`, `inject`, `load`, `extract`, `resolve` |
| Failure reason | Yes | Why the file was not found or the operation failed |
| Related module | Yes | The helper or script that triggered the error |
| Recovery/fallback | If exists | What action was taken after the failure |

---

## Standard Helper: `Write-FileError`

Located in `scripts/shared/logging.ps1`. All file/path errors across the
project should use this helper:

```powershell
Write-FileError -FilePath <path> -Operation <op> -Reason <reason> [-Module <name>] [-Fallback <action>]
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-FilePath` | string | Yes | Exact file path that was attempted |
| `-Operation` | string | Yes | One of: read, write, copy, move, inject, load, extract, resolve |
| `-Reason` | string | Yes | Human-readable reason for the failure |
| `-Module` | string | No | Name of the helper/script that triggered the error (auto-detected if omitted) |
| `-Fallback` | string | No | Description of the recovery action taken, if any |

### Output Format

The helper produces a structured error message:

```
[CODE RED] File error during {operation}: {path} -- Reason: {reason} [Module: {module}]
```

And records a structured event with all fields.

---

## File and Path Error Categories

| Category | What to log |
|----------|-------------|
| Missing file | Exact path + why it is considered missing |
| Invalid path | Exact invalid path + what format/resolution failed |
| Missing generated file | Expected output path + which previous step failed to create it |
| Missing uploaded/extracted file | Extraction target path + whether archive/upload/placement step failed |
| Injection/asset load failure | Exact asset path + whether failure was resolution, existence, permission, or dependency |

---

## Acceptable Failure Reasons

- File does not exist
- Path is invalid
- Path is inaccessible
- File name mismatch
- Extension mismatch
- Permission denied
- File was expected from a prior step but was never created
- File was removed, moved, or renamed

---

## Scope of Application

This rule applies to **every module** that handles file or path operations:

| Module | File |
|--------|------|
| JSON config loader | `scripts/shared/logging.ps1` (`Import-JsonConfig`) |
| Backup utility | `scripts/shared/json-utils.ps1` (`Backup-File`) |
| Resolved data writer | `scripts/shared/resolved.ps1` |
| Cleanup utility | `scripts/shared/cleanup.ps1` |
| Symlink utility | `scripts/shared/symlink-utils.ps1` |
| PATH utility | `scripts/shared/path-utils.ps1` |
| Settings sync | `scripts/11-vscode-settings-sync/helpers/sync.ps1` |
| NPP settings sync | `scripts/33-install-notepadpp/helpers/notepadpp.ps1` |
| All individual script helpers | `scripts/*/helpers/*.ps1` |

---

## Open Questions (Documented, Not Assumed)

1. Whether all file-related **warnings** (not just errors) should also include exact paths.
   - **Decision**: Yes -- warnings should also include paths for consistency.
2. Whether sensitive paths require masking in any environment.
   - **Decision**: Not currently -- all paths are local developer machine paths.
3. Whether this rule applies to UI/DevTools output or only runtime logs.
   - **Decision**: Runtime logs only (PowerShell console + JSON log files).

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Centralised `Write-FileError` helper | Prevents inconsistency; enforces all required fields |
| Auto-detect module name from call stack | Reduces boilerplate at call sites |
| Structured event with all fields | Machine-parseable for future monitoring |
| Code-red severity | File path errors are the #1 cause of silent failures |

```
Do you understand? Can you please do that?
```
