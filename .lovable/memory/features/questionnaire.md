---
name: Front-loaded questionnaire pattern
description: Script 12 asks all config questions upfront (dev dir, VS Code editions, sync mode), stores in env vars, child scripts run unattended. -D flag skips all prompts with defaults.
type: feature
---
## Front-loaded questionnaire

Script 12 uses a 3-option quick menu:
1. All Dev (no DBs) -- IDs 01-11, 16-17, 31
2. All Dev + All DBs -- adds 18-29
3. Custom -- full interactive checkbox menu

All config questions (dev dir, VS Code editions, sync mode, Git name/email) are asked BEFORE any scripts run.

### Environment variables set by questionnaire

| Variable | Default | Consumed by |
|----------|---------|-------------|
| `$env:DEV_DIR` | config.json `devDir.default` | `shared/dev-dir.ps1`, `06-golang` (GOPATH) |
| `$env:VSCODE_EDITIONS` | `stable` | `01-install-vscode` |
| `$env:VSCODE_SYNC_MODE` | `overwrite` | `11-vscode-settings-sync` |
| `$env:GIT_USER_NAME` | existing git config or skip | `07-install-git` |
| `$env:GIT_USER_EMAIL` | existing git config or skip | `07-install-git` |
| `$env:SCRIPTS_ROOT_RUN` | set to `1` by orchestrator | `09-cpp` (MinGW default path), `15-windows-tweaks` (skip confirmation) |

## -D / -Defaults flag
- `.\run.ps1 -D` runs alldev mode with all default answers, zero prompts
- Can combine with `-Only` or `-Skip` to filter scripts while still using defaults
- Defaults: dev dir from config.json, VS Code = stable, sync = overwrite, Git name/email = existing or skip
- Individual scripts still prompt when run standalone (no env vars set)

## DB install approach
- Chocolatey free edition does NOT support `--install-directory`
- All DB scripts install to system default location
- No install-path prompts in individual DB run.ps1 files
