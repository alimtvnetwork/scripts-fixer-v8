# Spec: Install Simple Sticky Notes (Script 34)

## Overview

Script 34 installs **Simple Sticky Notes** via Chocolatey -- a lightweight
desktop sticky notes application for Windows. Optionally redirects the SSN
data folder to a custom location (e.g. `D:\notes`) via directory symlink.

---

## Usage

```powershell
.\run.ps1 install sticky-notes       # Install Simple Sticky Notes
.\run.ps1 install stickynotes        # Alias
.\run.ps1 install ssn                # Short alias
.\run.ps1 -I 34                      # By script ID
.\run.ps1 -I 34 -- -Help             # Show help
```

## Keywords

| Keyword | Script ID |
|---------|-----------|
| `sticky-notes` | 34 |
| `stickynotes` | 34 |
| `sticky` | 34 |
| `ssn` | 34 |

---

## Config (`config.json`)

| Field | Value |
|-------|-------|
| `chocoPackage` | `simple-sticky-notes` |
| `enabled` | `true` |
| `verifyCommand` | `SimpleSticky` |
| `dataFolder.enabled` | `true` |
| `dataFolder.path` | `D:\notes` |
| `dataFolder.createIfMissing` | `true` |

---

## Execution Flow

1. Check if Simple Sticky Notes is already installed (common paths + `Get-Command`)
2. If found, log and skip
3. If missing, install via `choco install simple-sticky-notes -y`
4. Verify EXE exists at expected path after install (CODE RED: exact path logged on failure)
5. Save install record to `.installed/sticky-notes.json`
6. Save resolved state to `.resolved/34-install-sticky-notes/resolved.json`
7. If `dataFolder.enabled`, redirect SSN data to custom path via symlink

---

## Custom Data Folder

When `dataFolder.enabled` is `true`, the script:

1. Creates the target folder (e.g. `D:\notes`) if missing and `createIfMissing` is true
2. If `%APPDATA%\Simple Sticky Notes` exists as a real folder, moves its contents to the target
3. Creates a directory symlink: `%APPDATA%\Simple Sticky Notes` → `D:\notes`
4. If the symlink already points to the correct target, skips silently

This ensures SSN reads/writes all data (notes database, settings) from the custom location.

---

## Verification Paths

- `$env:ProgramFiles\Simple Sticky Notes\SimpleSticky.exe`
- `${env:ProgramFiles(x86)}\Simple Sticky Notes\SimpleSticky.exe`

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Simple Sticky Notes (Choco) | User selected over Microsoft Sticky Notes (UWP) or Stickies |
| EXE verification post-install | CODE RED rule: exact path logged if not found |
| `Install-ChocoPackage` helper | Consistent with all other Choco-based scripts |
| Symlink for data folder | Non-destructive redirect; SSN unaware of relocation |
| `createIfMissing` flag | Safety switch to prevent accidental folder creation |

## Install Keywords

| Keyword |
|---------|
| `sticky-notes` |
| `stickynotes` |
| `sticky` |
| `ssn` |

```powershell
.\run.ps1 install sticky-notes
```
