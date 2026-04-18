# Reliability Report: Scripts 42 (Ollama) & 43 (llama.cpp)

**Date:** 2026-04-15
**Version:** v0.23.0 (post-fixes)
**Status:** P1/P2 fixes applied -- reassessed

---

## Executive Summary

Both scripts follow the established project patterns (JSON config, structured
logging, installed tracking, resolved state, uninstall support). All P1 and P2
items from the initial assessment have been resolved. Remaining risks are
cosmetic or low-probability edge cases.

| Category | Script 42 (Ollama) | Script 43 (llama.cpp) |
|----------|--------------------|-----------------------|
| Overall Risk | **Low** | **Low-Medium** |
| Error Handling | Good | Good |
| Network Resilience | **Good** (was Low) | **Good** (was Low) |
| Idempotency | Good | **Excellent** (ZIP integrity) |
| Uninstall Safety | Good | Good |
| Disk Space Awareness | **Good** (warn-only) | **Good** (blocking for exes, warn for models) |

---

## Fixes Applied Since Initial Report

| # | Priority | Fix | Status | Details |
|---|----------|-----|--------|---------|
| 1 | **P1** | Download retry with exponential backoff | **RESOLVED** | Shared `Invoke-DownloadWithRetry` in `scripts/shared/download-retry.ps1` -- 3 attempts, exponential backoff (5s/10s/20s), partial file cleanup on final failure |
| 2 | **P1** | Partial/corrupt ZIP detection | **RESOLVED** | `Test-ZipIntegrity` in `llama-cpp.ps1` validates magic bytes (`PK\x03\x04`) + expected file size (+-10% tolerance); auto-deletes and re-downloads corrupt files |
| 3 | **P2** | Suppress prompts under orchestrator | **RESOLVED** | Both scripts check `$env:SCRIPTS_ROOT_RUN = "1"` and skip `Read-Host` for models directory + model pull confirmations |
| 4 | **P2** | Disk space pre-check | **RESOLVED** | Shared `Test-DiskSpace` + `Get-TotalDownloadSize` in `scripts/shared/disk-space.ps1`; Script 43 blocks on insufficient exe space, warns for models; Script 42 warns for full install (~12 GB) |
| 5 | **P2** | Validate pinned GitHub URLs | **RESOLVED** | `Test-UrlFreshness` in `scripts/shared/url-freshness.ps1` -- HEAD-checks all download URLs before starting; blocks for executables, warns for models |

---

## Script 42: Install Ollama

### Strengths

| # | Item |
|---|------|
| 1 | Silent installer with exit-code checking (`/VERYSILENT /NORESTART`) |
| 2 | Already-installed detection via `Get-Command ollama` before downloading |
| 3 | Version tracking through `.installed/ollama.json` |
| 4 | Resolved state saved with timestamp for audit trail |
| 5 | Uninstaller searches two known paths (`LOCALAPPDATA`, `Program Files`) |
| 6 | `OLLAMA_MODELS` env var set at User scope (survives reboots) |
| 7 | PATH refresh after install for immediate CLI availability |
| 8 | Prompt for custom models directory with sensible default |
| 9 | Model pull is per-model opt-in (user confirms each) |
| 10 | Full try/catch with `Save-InstalledError` on failure |
| 11 | **NEW:** Download retry with exponential backoff (3 attempts) |
| 12 | **NEW:** Orchestrator mode auto-accepts models dir + pull confirmations |
| 13 | **NEW:** Disk space pre-check (~12 GB warning) before full install |

### Remaining Issues

| # | Severity | Issue | Impact | Recommendation |
|---|----------|-------|--------|----------------|
| 1 | **MEDIUM** | Hardcoded download URL in config.json | `https://ollama.com/download/OllamaSetup.exe` may change on major releases | Consider fetching latest URL from ollama.com API |
| 2 | **MEDIUM** | `ollama pull` has no timeout | Large models (4-5 GB) can hang indefinitely on slow connections | Wrap with `Invoke-WithTimeout` or document expected duration |
| 3 | **LOW** | Version parse assumes `ollama --version` returns digits | If Ollama changes output format, version tracking stores garbage | Already handled with regex fallback |
| 4 | **LOW** | Temp directory cleanup not performed | Downloaded `OllamaSetup.exe` stays in dev dir after install | Add cleanup step or document as intentional cache |

### Edge Cases

| Scenario | Current Behaviour | Risk |
|----------|-------------------|------|
| Ollama installed by MSI (not InnoSetup) | Uninstaller paths won't match | Uninstall silently fails, reports error |
| Ollama installed via `winget` | `Get-Command ollama` finds it, skips install | Correct -- no conflict |
| User has custom OLLAMA_MODELS already set | Overwrites with new path | Should warn and confirm before overwriting |
| No internet connectivity | Download retries 3x then fails gracefully | **IMPROVED** -- was single-attempt |
| Antivirus blocks OllamaSetup.exe | Installer fails with access denied | Exit code check catches it |
| Disk full during model pull | `ollama pull` fails with OS error | Disk pre-check warns before starting |

---

## Script 43: Install llama.cpp

### Strengths

| # | Item |
|---|------|
| 1 | Config-driven executable list (add/remove variants without code changes) |
| 2 | Per-executable skip logic (checks file size + extracted bin folder) |
| 3 | ZIP extraction with nested-folder fallback search (`Get-ChildItem -Recurse`) |
| 4 | Each executable tracked individually (`llama-cpp-{slug}`) |
| 5 | `Write-FileError` called on download/extract failures (CODE RED compliance) |
| 6 | PATH entries added per-binary with dedup check (`Test-InPath`) |
| 7 | Uninstall removes folders, PATH entries, and tracking per executable |
| 8 | Idempotent -- re-running skips already-downloaded files |
| 9 | Session PATH refresh after all executables processed |
| 10 | Models directory prompt with user override |
| 11 | **NEW:** Download retry with exponential backoff (3 attempts) |
| 12 | **NEW:** ZIP integrity validation (magic bytes + expected size +-10%) |
| 13 | **NEW:** Auto-delete and re-download of corrupt/partial ZIPs |
| 14 | **NEW:** Orchestrator mode skips models directory prompt |
| 15 | **NEW:** Disk space pre-check (blocking for executables, warning for models) |
| 16 | **NEW:** `expectedSizeBytes` in config.json for all ZIP executables |

### Remaining Issues

| # | Severity | Issue | Impact | Recommendation |
|---|----------|-------|--------|----------------|
| 1 | ~~MEDIUM~~ | ~~Hardcoded pinned release URLs~~ | ~~Resolved~~ | `Test-UrlFreshness` validates all URLs before download |
| 2 | **MEDIUM** | No download progress indicator for large files | `SilentlyContinue` suppresses progress for multi-GB files | Show size estimate and elapsed time |
| 3 | **LOW** | KoboldCPP EXE naming may cause PATH confusion | Both `koboldcpp.exe` and `koboldcpp_nocuda.exe` in PATH | Works correctly but may confuse users |
| 4 | **LOW** | ZIP extraction uses `-Force` (overwrites silently) | Re-extraction overwrites user modifications | Document as intentional |
| 5 | **LOW** | HuggingFace model URLs may require auth for gated models | Current models are public; future additions might be gated | Add auth token support in config |

### Edge Cases

| Scenario | Current Behaviour | Risk |
|----------|-------------------|------|
| GitHub rate-limits unauthenticated downloads | Retries 3x with backoff; fails gracefully | **IMPROVED** -- was single-attempt |
| ZIP contains unexpected folder structure | Nested-folder fallback search finds exe | Correct -- robust handling |
| Partial ZIP from previous failed download | **ZIP integrity check detects and re-downloads** | **RESOLVED** -- was skipping corrupt files |
| User PATH exceeds 2048 chars (Windows limit) | `Add-ToUserPath` may truncate or fail silently | PATH corruption risk on systems with many tools |
| AVX2 not supported on CPU | Binary downloaded but crashes on execution | No CPU feature detection |
| CUDA not installed | CUDA variants downloaded but won't run | No CUDA detection; wastes bandwidth |
| Antivirus quarantines koboldcpp.exe | File disappears after download; next run re-downloads | Self-healing via idempotent download |
| Insufficient disk space for executables | **Script blocks with clear error message** | **RESOLVED** -- was silent failure |

---

## Cross-Script Concerns

### 1. Network Resilience (Both Scripts) -- RESOLVED

**Previous state:** Single-attempt `Invoke-WebRequest` with no retry.

**Current state:** Shared `Invoke-DownloadWithRetry` helper provides:
- 3 retry attempts with exponential backoff (5s, 10s, 20s)
- File existence and zero-byte validation after each attempt
- Partial file cleanup on final failure
- Per-attempt logging with error details

### 2. Orchestrator Integration (Both Scripts) -- RESOLVED

**Previous state:** `Read-Host` prompts blocked Script 12 during unattended execution.

**Current state:** Both scripts check `$env:SCRIPTS_ROOT_RUN = "1"` and:
- Ollama: uses default models directory, auto-accepts all model pulls
- llama.cpp: uses default models directory

### 3. Disk Space (Both Scripts) -- RESOLVED

**Previous state:** No pre-flight disk space checking.

**Current state:** Shared `Test-DiskSpace` + `Get-TotalDownloadSize` helpers:
- Script 42: warns if <12 GB free (non-blocking, since Ollama pull handles its own errors)
- Script 43: blocks executables install if insufficient space (sums `expectedSizeBytes`), warns for models

Combined worst-case download size:

| Component | Size |
|-----------|------|
| OllamaSetup.exe | ~100 MB |
| Ollama models (3x) | ~11.6 GB |
| llama.cpp ZIPs (4x) | ~1.2 GB |
| KoboldCPP EXEs (2x) | ~200 MB |
| GGUF models (5x) | ~68 GB |
| **Total** | **~81 GB** |

### 4. File Integrity (Script 43) -- RESOLVED

**Previous state:** Partial ZIPs (size > 0) were skipped as "already downloaded".

**Current state:** `Test-ZipIntegrity` validates:
- ZIP magic header bytes (`PK\x03\x04`)
- File size within +-10% of `expectedSizeBytes` from config
- Auto-deletes invalid files and triggers re-download

### 5. URL Freshness -- RESOLVED

Script 43 now runs `Test-UrlFreshness` (from `scripts/shared/url-freshness.ps1`)
before starting any downloads:

- **Executables:** HEAD-checks all URLs; blocks install if any return non-200
- **Models:** HEAD-checks all URLs; logs warnings but continues (warn-only)

| Script | URL Type | Staleness Risk |
|--------|----------|----------------|
| 42 | `ollama.com/download/OllamaSetup.exe` | Low (stable URL) |
| 43 | GitHub pinned releases (`b7709`, `b6869`) | **Mitigated** (pre-validated) |
| 43 | GitHub `latest` releases | Low (always resolves) |
| 43 | HuggingFace model URLs | Low (pre-validated, warn-only) |

---

## Remaining Priority Fixes

| Priority | Fix | Effort | Scripts | Status |
|----------|-----|--------|---------|--------|
| ~~P1~~ | ~~Download retry with backoff~~ | ~~2h~~ | ~~Both~~ | **DONE** |
| ~~P1~~ | ~~Partial/corrupt file detection~~ | ~~2h~~ | ~~43~~ | **DONE** |
| ~~P2~~ | ~~Suppress prompts under orchestrator~~ | ~~1h~~ | ~~Both~~ | **DONE** |
| ~~P2~~ | ~~Disk space pre-check~~ | ~~1h~~ | ~~Both~~ | **DONE** |
| ~~P2~~ | ~~Validate pinned GitHub URLs still resolve~~ | ~~1h~~ | ~~43~~ | **DONE** |
| P3 | Add CUDA/AVX2 CPU feature detection | 2h | 43 | OPEN |
| P3 | Add file integrity (SHA256) verification | 2h | Both | OPEN |
| P3 | Add download progress indicator for large files | 2h | 43 | OPEN |
| P3 | Add `ollama pull` timeout wrapper | 1h | 42 | OPEN |

---

## Test Matrix

| Test Case | Script | Expected Result | Status |
|-----------|--------|-----------------|--------|
| Fresh install (no Ollama, no llama.cpp) | Both | Full install, tracking created | Untested |
| Re-run after successful install | Both | Skips downloads, "already installed" messages | Untested |
| Run without admin rights | Both | Exits with admin-required error | Untested |
| Run with `--help` | Both | Shows help, no side effects | Untested |
| Run with `-Path C:\custom` | Both | Uses custom dev directory | Untested |
| Run under Script 12 (`$env:SCRIPTS_ROOT_RUN=1`) | Both | **Uses defaults, no prompts** | **FIXED** |
| Network disconnect during download | Both | **Retries 3x with backoff, then fails gracefully** | **FIXED** |
| Partial ZIP from previous failed download | 43 | **Detects corrupt ZIP, re-downloads** | **FIXED** |
| Insufficient disk space | Both | **Warns or blocks before downloading** | **FIXED** |
| Uninstall then reinstall | Both | Clean uninstall, fresh reinstall works | Untested |
| Disk full during model download | Both | Error caught, logged, script continues | Untested |
| Invalid/changed download URL | Both | Error caught after retries, logged | Untested |

---

## Conclusion

All P1 and P2 items have been resolved. Both scripts now have **robust network
resilience** (3-attempt retry with exponential backoff), **file integrity
validation** (ZIP header + size checks for Script 43), **silent orchestrator
mode** (no interactive prompts under Script 12), and **disk space pre-checks**
(blocking or warning based on context).

**Overall risk has been reduced from Medium/Medium-High to Low/Low-Medium.**

Remaining P2/P3 items are quality-of-life improvements (progress indicators,
CPU feature detection, SHA256 checksums) that do not affect core reliability.
The next recommended action is a periodic URL freshness audit for pinned
GitHub release URLs in Script 43.
