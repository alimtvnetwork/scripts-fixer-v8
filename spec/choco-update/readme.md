# Spec: Choco Update Command

## Overview

The `.\run.ps1 update` command checks for outdated Chocolatey packages,
displays a formatted table, and upgrades them with user confirmation.
Supports selective updates, check-only mode, auto-confirm, and exclude lists.

---

## Usage

```powershell
.\run.ps1 update                              # Show outdated, confirm, upgrade all
.\run.ps1 update nodejs,git                   # Upgrade specific packages only
.\run.ps1 update --check                      # List outdated packages (no upgrade)
.\run.ps1 update -y                           # Upgrade all, skip confirmation
.\run.ps1 update nodejs -y                    # Upgrade nodejs, skip confirmation
.\run.ps1 update --exclude=chocolatey,dotnet  # Upgrade all except listed
.\run.ps1 upgrade                             # Alias for update
.\run.ps1 choco-update                        # Alias for update
```

---

## Execution Flow

### Default (no arguments)

1. Verify Chocolatey is installed (`choco.exe` in PATH)
2. Run `choco outdated --limit-output` to find packages with available updates
3. Display formatted table: Package | Current | Available
4. Show count of outdated packages
5. Prompt: "Upgrade N package(s)? [Y/n]"
6. If confirmed, run `choco upgrade all -y`
7. Report success or failure

### Selective Update (`update <packages>`)

1. Parse comma-separated package names from remaining arguments
2. Confirm with user (unless `-y`)
3. Upgrade each package individually via `choco upgrade <name> -y`
4. Report per-package success/failure and summary

### Check-Only (`update --check`)

1. Run `choco outdated --limit-output`
2. Display outdated table
3. Exit without upgrading

### Auto-Confirm (`update -y`)

1. Same as default flow but skips the [Y/n] prompt
2. Also works with selective: `update nodejs -y`

### Exclude (`update --exclude=pkg1,pkg2`)

1. Run `choco outdated --limit-output`
2. Filter out excluded packages from the outdated list
3. Upgrade remaining packages individually
4. Report per-package results

---

## Accepted Commands

| Command | Behaviour |
|---------|-----------|
| `update` | Outdated check + confirm + upgrade all |
| `update nodejs,git` | Upgrade specific packages only |
| `update --check` | List outdated, no upgrade |
| `update -y` | Upgrade all, skip confirmation |
| `update --exclude=pkg1,pkg2` | Upgrade all except listed |
| `upgrade` | Alias for `update` |
| `choco-update` | Alias for `update` |

---

## Argument Parsing

Arguments after `update` are parsed from positional remaining args:

| Pattern | Effect |
|---------|--------|
| `--check` or `-check` | Sets check-only mode |
| `-y` or `--yes` | Sets auto-confirm mode |
| `--exclude=pkg1,pkg2` | Sets exclusion list (comma-separated after `=`) |
| Anything else | Treated as package name(s), split on commas |

The root `-Y` switch is also honored for auto-confirm.

---

## Implementation

| File | Purpose |
|------|---------|
| `scripts/shared/choco-update.ps1` | `Get-ChocoOutdated`, `Show-OutdatedTable`, `Invoke-ChocoUpdate` |
| `run.ps1` | Argument parsing, delegates to `Invoke-ChocoUpdate` |

### Functions

| Function | Purpose |
|----------|---------|
| `Get-ChocoOutdated` | Runs `choco outdated --limit-output`, returns structured array |
| `Show-OutdatedTable` | Formats and displays the outdated packages table |
| `Invoke-ChocoUpdate` | Main entry point with all update modes |

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| `choco outdated` instead of `choco list` | Shows only actionable updates, not all packages |
| `--limit-output` flag | Machine-parseable pipe-delimited output |
| Individual upgrades for exclude mode | `choco upgrade all` has no native `--except` support |
| Auto-confirm via both `-y` arg and `-Y` switch | Consistent with existing Defaults mode pattern |
| Check-only exits cleanly | No side effects, safe for CI/scheduled checks |
