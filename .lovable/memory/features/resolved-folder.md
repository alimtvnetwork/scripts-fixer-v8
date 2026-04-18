---
name: Resolved folder pattern
description: Runtime-discovered state goes to .resolved/ (gitignored), never into config.json. Shared helper resolved.ps1 provides Save-ResolvedData.
type: feature
---
## Rule
Scripts must NEVER mutate their own `config.json` with runtime-discovered data (resolved paths, timestamps, etc.). Config files are **declarative input only**.

## Where runtime state goes
All resolved/discovered data is written to `<repo-root>/.resolved/<script-folder>/resolved.json` using the shared helper `scripts/shared/resolved.ps1`.

## Shared helper functions
- `Get-ResolvedDir -ScriptDir <string>` -- returns and creates `.resolved/<script-folder>/`
- `Save-ResolvedData -ScriptDir <string> -Data <hashtable>` -- merges new keys into existing resolved.json

## Cache-first pattern
Scripts should check `.resolved/` before running expensive detection. If the cached value is still valid (e.g. exe exists on disk), skip detection. If stale, fall through to normal detection and re-cache.

## Folder structure
```
.resolved/                              (gitignored)
├── 01-vscode-context-menu-fix/
│   └── resolved.json
└── 02-vscode-settings-sync/
    └── resolved.json
```
