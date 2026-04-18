---
name: Uninstall command for all scripts
description: Every run.ps1 supports an uninstall subcommand that does full cleanup
type: feature
---
All scripts (01-38) now support an `uninstall` subcommand that performs full cleanup:

1. **Chocolatey uninstall** -- `Uninstall-ChocoPackage` (shared helper in choco-utils.ps1)
2. **Environment variables** -- remove any env vars the script sets (User scope)
3. **PATH cleanup** -- `Remove-FromUserPath` (shared helper in path-utils.ps1)
4. **Dev directory subfolder** -- delete the tool's subfolder under dev dir
5. **Tracking records** -- `Remove-InstalledRecord` + `Remove-ResolvedData` (shared helpers)

Shared helpers used:
- `Uninstall-ChocoPackage` in choco-utils.ps1
- `Remove-InstalledRecord` in installed.ps1
- `Remove-ResolvedData` in resolved.ps1
- `Remove-FromUserPath` in path-utils.ps1

Log messages pattern: all scripts use `uninstalling`, `uninstallSuccess`, `uninstallFailed`, `uninstallComplete` message keys with `{name}` placeholder.

Scripts with special uninstall behavior:
- 02 (Chocolatey): No uninstall -- would break everything
- 04 (pnpm): Uses `npm uninstall -g pnpm` instead of choco
- 10 (VS Code Context Menu): Registry key cleanup
- 11 (VS Code Settings Sync): Tracking cleanup only (preserves user settings)
- 14 (Winget): Tracking cleanup only (system component)
- 15 (Windows Tweaks): Tracking cleanup only (tweaks can't be auto-reverted)
- 29 (LiteDB): Uses `dotnet tool uninstall` instead of choco
- 31 (PowerShell Context Menu): Registry key cleanup
- 35 (GitMap): Custom install dir removal (not choco-based)

Implementation complete across all scripts.
