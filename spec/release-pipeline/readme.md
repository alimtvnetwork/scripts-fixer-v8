# Release Pipeline

## Overview

`release.ps1` packages project assets into a versioned ZIP archive under the `.release/` directory. The version is read from `.gitmap/release/latest.json`.

## Output

```
.release/dev-tools-setup-v<version>.zip
```

## Contents of the ZIP

| Item               | Type      | Description                              |
|--------------------|-----------|------------------------------------------|
| `scripts/`         | Directory | All numbered script folders + shared/    |
| `run.ps1`          | File      | Root dispatcher                          |
| `bump-version.ps1` | File      | Version bump utility                     |
| `readme.md`        | File      | Project readme                           |
| `LICENSE`          | File      | License file                             |
| `changelog.md`     | File      | Changelog                                |

## Parameters

| Parameter  | Type   | Description                                      |
|------------|--------|--------------------------------------------------|
| `-Force`   | Switch | Overwrite an existing ZIP for the same version    |
| `-DryRun`  | Switch | Preview what would be packaged without creating   |

## Usage

```powershell
# Build release ZIP for current version
.\release.ps1

# Preview contents without creating ZIP
.\release.ps1 -DryRun

# Overwrite existing ZIP
.\release.ps1 -Force
```

## Workflow

1. Reads version from `.gitmap/release/latest.json`
2. Creates `.release/` directory if missing
3. Stages `scripts/`, `run.ps1`, `bump-version.ps1`, `readme.md`, `LICENSE`, `changelog.md` into a temp directory
4. Compresses staged files into `dev-tools-setup-v<version>.zip`
5. Reports file count and ZIP size
6. Cleans up the staging directory

## Notes

- Missing source files are skipped with a warning (not a failure)
- Existing ZIP for the same version is skipped unless `-Force` is used
- The `.release/` folder should be added to `.gitignore`
