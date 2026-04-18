# Spec: Audit Mode

## Overview

A dedicated audit script that scans the entire project for stale IDs,
mismatched folder names, missing cross-references, and renumbering
inconsistencies. Designed to run after any renumbering or restructuring.

## Checks Performed

| # | Check | Description |
|---|-------|-------------|
| 1 | **Registry vs folders** | Every ID in `scripts/registry.json` must map to an existing folder under `scripts/`. Every numbered folder must appear in the registry. |
| 2 | **Orchestrator config vs registry** | Every ID in `scripts/12-install-all-dev-tools/config.json` `sequence` and `scripts` must exist in the registry. |
| 3 | **Orchestrator groups vs scripts** | Every ID referenced in `config.json` `groups[].ids` must exist in the `scripts` block. |
| 4 | **Spec folder coverage** | Every numbered script folder must have a matching `spec/<folder>/readme.md`. |
| 5 | **Config + log-messages existence** | Every script folder must contain `config.json` and `log-messages.json`. |
| 6 | **Stale ID references in specs** | Scan `spec/**/*.md` for patterns like `Script NN` or `scripts/NN-` that reference non-existent IDs. |
| 7 | **Stale ID references in suggestions** | Scan `suggestions/**/*.md` for the same stale-reference patterns. |
| 8 | **Stale ID references in PowerShell** | Scan `scripts/**/*.ps1` for hardcoded folder references like `01-install-vscode` and verify they match registry entries. |
| 9 | **Keyword modes vs config validModes** | Every mode value in `install-keywords.json` `modes` must exist in the target script's `config.json` `validModes` array. |
| 10 | **Verify database symlinks** | Scans `dev-tool\databases\` for broken junctions, missing links, and real directories. Supports `-Fix` and `-DryRun`. |
| 11 | **Uninstall coverage** | Every script (except 02, 12, audit, databases) must have: an `Uninstall-*` function in helpers, an `uninstall` command in `run.ps1`, and uninstall help in `log-messages.json`. |
| 12 | **Export coverage** | Every settings-capable script (32, 33, 36, 37) must have: an `Export-*` function in helpers, an `export` command in `run.ps1`, and export-related messages in `log-messages.json`. |

## Usage

```powershell
.\run.ps1 -I 13                   # Run full audit
.\run.ps1 -I 13 -- -DryRun        # Preview symlink repairs without changes
.\run.ps1 -I 13 -- -Fix           # Run audit and auto-fix broken symlinks
.\run.ps1 -I 13 -- -Report        # Run audit and save JSON health report
.\run.ps1 -I 13 -- -Help          # Show help
.\run.ps1 -h                      # Shortcut: audit + report
.\run.ps1 health                  # Keyword shortcut: audit (ID 13)
```

## Install Keywords

| Keyword |
|---------|
| `audit` |
| `health` |
| `health-check` |
| `healthcheck` |

## Output

- Each check prints PASS or FAIL with details
- Exit summary shows total pass/fail counts
- Non-zero exit code if any check fails

## Health Report (`-Report`)

When `-Report` is passed, a JSON file is saved to `logs/health-check_<timestamp>.json` containing:

| Field | Description |
|-------|-------------|
| `timestamp` | ISO 8601 timestamp of the run |
| `version` | Project version from `scripts/version.json` |
| `totalChecks` | Number of checks executed |
| `passed` | Count of passing checks |
| `failed` | Count of failing checks |
| `status` | `"healthy"` or `"unhealthy"` |
| `checks` | Array of per-check results with `passed` and `issues` |