# Suggestions: VS Code Context Menu Fix

## Potential Enhancements

1. **Uninstall / Rollback mode** — Add a `-Remove` switch to cleanly delete the registry entries.

2. **VS Code Insiders support** — Extend `config.json` to support VS Code Insiders paths and let users choose which edition to register.

3. **Windows 11 modern context menu** — Windows 11 hides classic entries behind "Show more options". Consider adding entries to the new-style context menu via `HKCR\Directory\shell\VSCode\` with `SubCommands` or using the `{86ca1aa0-34aa-4e8b-a509-50c905bae2a8}` workaround to force classic menus.

4. **Scheduled task / startup check** — Optionally register a scheduled task that re-applies the fix after major Windows updates (which sometimes reset context menus).

5. **GUI wrapper** — Create a simple WPF or WinForms dialog that lets non-technical users click a button instead of running PowerShell manually.

6. **Logging to file** — Write a timestamped log to `logs/` alongside the script for audit/troubleshooting purposes.
