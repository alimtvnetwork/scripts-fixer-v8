---
name: Shared helpers inventory
description: All shared PS1 helpers in scripts/shared/ -- logging, json-utils, resolved, git-pull, help, path-utils, choco-utils, dev-dir
type: feature
---
## scripts/shared/ inventory

| File | Functions | Purpose |
|------|-----------|---------|
| `logging.ps1` | `Write-Log`, `Write-Banner`, `Initialize-Logging`, `Save-LogFile`, `Import-JsonConfig` | Console output with status badges, centralised JSON log collection to `scripts/logs/`, JSON loading. `Write-Banner` auto-reads `scripts/version.json` for the project version. |
| `json-utils.ps1` | `Backup-File`, `ConvertTo-OrderedHashtable`, `Merge-JsonDeep` | File backups, PSCustomObject-to-hashtable conversion, recursive JSON merge |
| `resolved.ps1` | `Get-ResolvedDir`, `Save-ResolvedData` | Persist runtime state to `.resolved/` folder |
| `cleanup.ps1` | `Clear-ResolvedData` | Wipe .resolved/ contents (all or per-edition) for fresh detection |
| `git-pull.ps1` | `Invoke-GitPull` | Git pull with `$env:SCRIPTS_ROOT_RUN` skip guard |
| `help.ps1` | `Show-ScriptHelp` | Formatted --help output with commands, flags, examples |
| `path-utils.ps1` | `Test-InPath`, `Add-ToUserPath`, `Add-ToMachinePath` | Safe PATH manipulation with dedup checking |
| `choco-utils.ps1` | `Assert-Choco`, `Install-ChocoPackage`, `Upgrade-ChocoPackage` | Chocolatey install/upgrade wrappers with logging |
| `dev-dir.ps1` | `Resolve-DevDir`, `Initialize-DevDir` | Dev directory resolution (env/config/prompt) and creation |

## Logging system

- `Initialize-Logging -ScriptName "Install Golang"` -- starts event collection, resolves `scripts/logs/` dir
- Every `Write-Log` call records a `{timestamp, level, message}` event in memory
- `Save-LogFile -Status "ok"` -- writes `scripts/logs/golang.json` (all events) and `golang-error.json` (if errors)
- Error log is created when: any fail-level event was recorded OR overall status is "fail"
- Replaces old transcript-based logging (Start-Transcript)

## Rule
When adding new utility functions, check if they belong in an existing shared helper first. If reusable across scripts, put them in `scripts/shared/`. Script-specific helpers stay in `<script>/helpers/`.
