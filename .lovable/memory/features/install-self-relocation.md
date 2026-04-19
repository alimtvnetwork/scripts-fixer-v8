---
name: install-self-relocation
description: install.ps1 self-relocation flow when CWD is inside or contains scripts-fixer, plus stderr-noise fix
type: feature
---

# install.ps1 self-relocation & stderr fix

## Two bugs combined

1. **Stderr noise** — `git clone` writes `Cloning into '...'` to stderr.
   Using `2>&1` causes PowerShell to raise `NativeCommandError` (red text)
   even on a successful clone (exit 0). FIX: redirect stderr to a temp file
   (`2>$errFile`) and only show it on `$LASTEXITCODE -ne 0`. Use `--quiet`.

2. **Folder-in-use** — Running the bootstrap from inside
   `C:\Users\X\scripts-fixer` (or from a parent dir that contains a
   `scripts-fixer` subfolder) means `Remove-Item` may fail because the
   current shell holds a handle on the directory.

## Required flow

Detect: `$cwdLeaf -ieq 'scripts-fixer'` OR sibling `scripts-fixer` exists.

If detected:
1. `cd ..` when inside (releases handle).
2. Try `Remove-FolderSafe` (clears read-only bits, then `Remove-Item -Recurse -Force`).
3. Success → direct clone into `$folder`.
4. Failure → clone to `$env:TEMP\scripts-fixer-bootstrap-<timestamp>`,
   `Copy-Item -Recurse -Force` into `$folder`, cleanup temp.
5. `cd $folder` → `& .\run.ps1 -d`.

If NOT detected → direct clone, no relocation logs.

## Logging tags (required)

`[LOCATE]` `[CD]` `[CLEAN]` `[GIT]` `[OK]` `[INFO]` `[TEMP]` `[COPY]` `[ERROR]` `[WARN]`

Every log line must include the **exact path** involved (CODE RED rule).

## Why

- Users routinely re-run the one-liner from inside the cloned folder during
  testing — must not error out.
- Users on shared shells may have file locks — must have a fallback.
- Spec: `spec/install-bootstrap/readme.md` § "Self-Relocation Clone Flow".
