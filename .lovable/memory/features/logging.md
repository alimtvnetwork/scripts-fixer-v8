---
name: Logging location
description: Log files are stored in .logs/ at project root, not scripts/logs/
type: feature
---
Log output directory is `.logs/` at project root (parent of `scripts/`).
File naming: `<sanitised-script-name>.json` for normal logs, `<name>-error.json` for errors.
Version numbers in Write-Log output are highlighted in Yellow.
