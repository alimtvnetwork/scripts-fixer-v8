---
name: Path parameter for all scripts
description: Every run.ps1 accepts a -Path parameter to override the dev directory -- fully rolled out
type: feature
---
All 38 scripts support a `-Path` parameter so users can specify a custom dev directory.
When provided, it overrides smart drive detection and `$env:DEV_DIR`.

Pattern:
```powershell
param(
    [Parameter(Position = 0)]
    [string]$Command = "all",
    [Parameter(Position = 1)]
    [string]$Path,
    [switch]$Help
)
```

Resolution priority: `-Path` param > `$env:DEV_DIR` > smart detection.

Usage: `.\run.ps1 all F:\dev-tool` or `.\run.ps1 -Path E:\dev-tool`

Status: **Complete** -- rolled out to all scripts in v0.12.0.
