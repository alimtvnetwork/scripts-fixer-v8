# CI/CD Pipeline -- Specification & Known Issues

> **Purpose**: Document the current release pipeline, its known issues, root
> causes, and exact remediation steps. Written so any AI model (or human) can
> read this file alone and immediately understand and fix problems without
> needing to reverse-engineer the codebase.

---

## 1. Current State

### 1.1 What exists today

| Component                  | Path                              | Role                                          |
|----------------------------|-----------------------------------|-----------------------------------------------|
| Release packager           | `release.ps1`                     | Builds versioned ZIP into `.release/`         |
| Version bumper             | `bump-version.ps1`                | Increments `scripts/version.json` + gitmap    |
| Version source of truth    | `.gitmap/release/latest.json`     | Read by `release.ps1` to determine ZIP name   |
| Per-release manifest       | `.gitmap/release/v<x.y.z>.json`   | Changelog entries per version                 |
| Output directory           | `.release/`                       | Holds `dev-tools-setup-v<version>.zip`        |
| Release pipeline spec      | `spec/release-pipeline/readme.md` | High-level packaging documentation            |

### 1.2 What does NOT exist (gaps)

- ❌ **No CI/CD automation** -- no GitHub Actions, no Azure Pipelines, no
  any-other-CI workflow file in `.github/workflows/` or equivalent.
- ❌ **No automated release trigger** -- ZIP is only produced when a human
  runs `release.ps1` locally.
- ❌ **No automated tagging** -- `git tag v<version>` is manual.
- ❌ **No automated GitHub Release creation** -- the ZIP is never uploaded
  as a release asset.
- ❌ **No pre-release validation** -- nothing runs `Test-Path` checks,
  PSScriptAnalyzer, or smoke tests before packaging.
- ❌ **No changelog enforcement** -- nothing verifies that
  `.gitmap/release/v<version>.json` exists before packaging that version.
- ❌ **No ZIP integrity verification** -- nothing extracts the produced ZIP
  and re-runs `run.ps1 --help` to confirm the archive is usable.

---

## 2. Known Issues (with Root Cause Analysis)

Each issue below follows the format: **Symptom → Root Cause → Fix → Prevention**.
Anyone reading this section can apply the fix without further investigation.

---

### Issue #1: Version drift between `version.json` and `latest.json`

**Symptom**
- `release.ps1` produces `dev-tools-setup-v0.27.0.zip` while the README and
  `.lovable/overview.md` claim a different version.
- Users download an older ZIP than they expect.

**Root Cause**
- `release.ps1` reads version **only** from `.gitmap/release/latest.json`
  (line 44-46) and never cross-checks `scripts/version.json` or
  `changelog.md`.
- `bump-version.ps1` may update one source but not the other if the run is
  interrupted, or if a developer edits a file by hand.

**Fix (exact steps)**
1. In `release.ps1`, after line 46, add:
   ```powershell
   $versionJson  = Get-Content (Join-Path $RootDir "scripts/version.json") -Raw | ConvertFrom-Json
   $isVersionMismatch = $versionJson.version -ne $version
   if ($isVersionMismatch) {
       Write-Host "[ FAIL ] Version mismatch: latest.json=$version vs scripts/version.json=$($versionJson.version)" -ForegroundColor Red
       Write-Host "         Run .\bump-version.ps1 to realign, then retry." -ForegroundColor Yellow
       exit 1
   }
   ```
2. Mirror the same check against the most recent `.gitmap/release/v*.json`.

**Prevention**
- `bump-version.ps1` must update `scripts/version.json`,
  `.gitmap/release/latest.json`, and create `.gitmap/release/v<new>.json`
  in a single transaction (write to temp files, then move all at once).

---

### Issue #2: Missing changelog entry not detected

**Symptom**
- A release ZIP ships for `v0.28.0` but `.gitmap/release/v0.28.0.json` does
  not exist, so users have no record of what changed.

**Root Cause**
- `release.ps1` does not validate the existence of the per-version
  changelog manifest before packaging.

**Fix**
1. After reading `$version` in `release.ps1`, add:
   ```powershell
   $versionManifest = Join-Path $RootDir ".gitmap/release/v$version.json"
   $isManifestMissing = -not (Test-Path $versionManifest)
   if ($isManifestMissing) {
       Write-Host "[ FAIL ] Missing changelog manifest: $versionManifest" -ForegroundColor Red
       Write-Host "         Path checked: $versionManifest" -ForegroundColor DarkGray
       Write-Host "         Reason       : Required per-version changelog file does not exist." -ForegroundColor DarkGray
       exit 1
   }
   ```
2. Comply with the **CODE RED file-path-error rule**: log both the exact
   path and the failure reason.

**Prevention**
- Add a pre-commit hook or CI step that fails when
  `.gitmap/release/latest.json` references a version with no matching
  `v<version>.json`.

---

### Issue #3: Stale `.release/` ZIP overwritten silently with `-Force`

**Symptom**
- Developer runs `release.ps1 -Force` to regenerate, but accidentally
  overwrites a ZIP that was already published to GitHub Releases. The
  SHA256 of the live release no longer matches the local file.

**Root Cause**
- `release.ps1` line 153-155 deletes the existing ZIP without recording
  its hash or making a backup.

**Fix**
1. Before `Remove-Item $zipPath -Force`, compute and log a hash:
   ```powershell
   $oldHash = (Get-FileHash $zipPath -Algorithm SHA256).Hash
   $backupPath = "$zipPath.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
   Move-Item $zipPath $backupPath -Force
   Write-Host "  [ INFO ] Previous ZIP backed up: $backupPath" -ForegroundColor DarkCyan
   Write-Host "  [ INFO ] Previous SHA256       : $oldHash" -ForegroundColor DarkCyan
   ```
2. After creating the new ZIP, log its new hash and warn if it differs
   from the previous one.

**Prevention**
- Treat `.release/*.zip` as immutable once a tag is pushed. CI should
  refuse to overwrite a ZIP whose version matches an existing git tag.

---

### Issue #4: Staging directory leak on failure

**Symptom**
- `%TEMP%\dev-tools-release-<version>` accumulates over time when
  `Compress-Archive` throws (e.g., disk full, locked file).

**Root Cause**
- `release.ps1` cleans the staging directory only on the success path
  (line 168). There is no `try/finally` block.

**Fix**
Wrap lines 111-169 in:
```powershell
try {
    # staging + compression code
}
finally {
    if (Test-Path $stagingDir) {
        Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
```

**Prevention**
- All scripts that allocate temp directories must use `try/finally` for
  cleanup. Add this to `.lovable/strictly-avoid.md` as a forbidden
  pattern: "Allocating temp dirs without try/finally cleanup."

---

### Issue #5: Missing source files demoted to warnings

**Symptom**
- `LICENSE` or `changelog.md` is renamed/deleted; `release.ps1` ships the
  ZIP without them and only prints `[ WARN ] Skipping missing: LICENSE`.
  Users download an incomplete release.

**Root Cause**
- `release.ps1` line 126-129 treats missing required files as
  non-fatal warnings.

**Fix**
1. Mark each item as required or optional:
   ```powershell
   $includeItems = @(
       @{ Source = "scripts";          Type = "directory"; Required = $true  }
       @{ Source = "run.ps1";          Type = "file";      Required = $true  }
       @{ Source = "bump-version.ps1"; Type = "file";      Required = $true  }
       @{ Source = "readme.md";        Type = "file";      Required = $true  }
       @{ Source = "LICENSE";          Type = "file";      Required = $true  }
       @{ Source = "changelog.md";     Type = "file";      Required = $false }
   )
   ```
2. In the loop, fail when a required item is missing:
   ```powershell
   if (-not $isSourcePresent) {
       if ($item.Required) {
           Write-Host "[ FAIL ] Required source missing: $sourcePath" -ForegroundColor Red
           Write-Host "         Reason: File expected for release packaging." -ForegroundColor DarkGray
           exit 1
       }
       Write-Host "  [ WARN ] Skipping optional: $($item.Source)" -ForegroundColor Yellow
       continue
   }
   ```

**Prevention**
- Required-file list should be data-driven from a JSON config so a
  reviewer can see what ships in every release without reading code.

---

### Issue #6: ZIP not validated end-to-end

**Symptom**
- Release ZIP extracts cleanly but `run.ps1 --help` inside the extracted
  directory fails because a referenced `scripts/shared/*.ps1` was not
  copied.

**Root Cause**
- `release.ps1` never extracts and exercises the produced ZIP.

**Fix**
After successful compression, add a smoke test:
```powershell
$smokeDir = Join-Path $env:TEMP "dev-tools-smoke-$version"
if (Test-Path $smokeDir) { Remove-Item $smokeDir -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $smokeDir -Force
$smokeRun = Join-Path $smokeDir "run.ps1"
$isSmokeRunMissing = -not (Test-Path $smokeRun)
if ($isSmokeRunMissing) {
    Write-Host "[ FAIL ] Smoke test failed: $smokeRun missing after extraction." -ForegroundColor Red
    exit 1
}
& $smokeRun --help | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ FAIL ] Smoke test failed: run.ps1 --help exit code $LASTEXITCODE" -ForegroundColor Red
    exit 1
}
Remove-Item $smokeDir -Recurse -Force
Write-Host "  [ OK ] Smoke test passed." -ForegroundColor Green
```

**Prevention**
- Add this smoke test as a mandatory final step. CI must block the
  release tag if this fails.

---

### Issue #7: No automated CI workflow

**Symptom**
- Releases depend on a single developer remembering to run
  `release.ps1` after `bump-version.ps1`. ZIPs are never attached to
  GitHub Releases. Tags are pushed without artifacts.

**Root Cause**
- The repository has no `.github/workflows/` folder.

**Fix (proposed minimal workflow)**
Create `.github/workflows/release.yml`:
```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  package:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify version alignment
        shell: pwsh
        run: |
          $tag = "${{ github.ref_name }}".TrimStart('v')
          $latest = (Get-Content .gitmap/release/latest.json -Raw | ConvertFrom-Json).version
          if ($tag -ne $latest) {
              Write-Host "Tag $tag does not match latest.json $latest" -ForegroundColor Red
              exit 1
          }
      - name: Build release ZIP
        shell: pwsh
        run: ./release.ps1
      - name: Upload to GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: .release/dev-tools-setup-*.zip
          generate_release_notes: true
```

**Prevention**
- Document in `readme.md` that releases are produced by pushing a
  `v*.*.*` tag. No human should be uploading ZIPs by hand.

---

### Issue #8: `bump-version.ps1` is not idempotent / has no dry-run

**Symptom**
- Running `bump-version.ps1` twice in a row double-bumps the version
  (e.g., `v0.27.0 → v0.27.1 → v0.27.2`) when the developer expected
  the second run to be a no-op or a confirmation step.

**Root Cause**
- The bumper unconditionally increments. There is no `-DryRun` to
  preview the next version, and no check that `latest.json` was already
  bumped in this session.

**Fix**
1. Add `-DryRun` and `-Check` flags to `bump-version.ps1`.
2. `-DryRun` prints the current → next version without writing.
3. `-Check` exits 0 if the working tree's `latest.json` matches the
   most recent git tag (i.e., a bump is needed) and exits 1 otherwise.

**Prevention**
- CI runs `bump-version.ps1 -Check` on PRs and fails if the bump was
  forgotten.

---

## 3. Quick-Reference Fix Matrix

| Issue | Severity | File to edit             | One-line summary                                         |
|-------|----------|--------------------------|----------------------------------------------------------|
| #1    | High     | `release.ps1`            | Cross-check `scripts/version.json` against `latest.json` |
| #2    | High     | `release.ps1`            | Require `.gitmap/release/v<version>.json` to exist       |
| #3    | Medium   | `release.ps1`            | Backup + hash-log existing ZIP before overwrite          |
| #4    | Medium   | `release.ps1`            | Wrap staging in try/finally                              |
| #5    | High     | `release.ps1`            | Mark required files; fail on missing                     |
| #6    | High     | `release.ps1`            | Extract + smoke-test the produced ZIP                    |
| #7    | Critical | `.github/workflows/`     | Add tag-triggered release workflow                       |
| #8    | Medium   | `bump-version.ps1`       | Add `-DryRun` and `-Check` flags                         |

---

## 4. Acceptance Criteria for "CI/CD is Done"

A future PR can close the CI/CD epic only when **all** of the following are
true:

- [ ] `.github/workflows/release.yml` exists and runs on `v*.*.*` tags.
- [ ] `release.ps1` exits non-zero on version mismatch (Issue #1).
- [ ] `release.ps1` exits non-zero on missing per-version changelog (#2).
- [ ] `release.ps1` backs up overwritten ZIPs (#3).
- [ ] `release.ps1` cleans staging on failure (#4).
- [ ] `release.ps1` distinguishes required vs optional sources (#5).
- [ ] `release.ps1` smoke-tests the produced ZIP (#6).
- [ ] `bump-version.ps1` supports `-DryRun` and `-Check` (#8).
- [ ] GitHub Releases page shows ZIP assets attached automatically.
- [ ] Documentation in `spec/release-pipeline/readme.md` references this
      file for the failure modes.

---

## 5. Conventions for Error Logging (CODE RED reminder)

Every file/path failure introduced by CI/CD work **must** emit:

1. The exact path that was checked (absolute or repo-relative).
2. The reason the check failed in plain English.
3. A suggested next action when possible.

Example template:
```
[ FAIL ] <one-line summary>
         Path  : <full path>
         Reason: <why this failed>
         Action: <what the user should do next>
```

This rule is non-negotiable -- it is part of the project's core memory.

---

## 6. References

- High-level packaging spec: `spec/release-pipeline/readme.md`
- Version bumper spec       : `spec/bump-version/readme.md`
- Version source of truth   : `.gitmap/release/latest.json`
- Project memory index      : `.lovable/memory/index.md`
- Strictly-avoid list       : `.lovable/strictly-avoid.md`
