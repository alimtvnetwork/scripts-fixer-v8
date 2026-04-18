---
name: Current workflow status
description: What is done and what is pending as of v0.36.0
type: feature
---

# Workflow Status -- v0.36.0 (2026-04-18)

## ✅ Done This Session (v0.34.0 → v0.36.0)

| Task | Status | Details |
|------|--------|---------|
| `models search <query>` -- Ollama Hub live search | ✅ Done | `scripts/models/helpers/ollama-search.ps1`, x-test-* regex parser, CSV dispatch via `OLLAMA_PULL_MODELS` |
| `models uninstall` orchestrator subcommand | ✅ Done | Multi-backend (llama.cpp + Ollama), multi-select, yes-confirm, `scripts/models/helpers/uninstall.ps1` |
| `-Force` flag for `models uninstall` (v0.34.1) | ✅ Done | Skips confirm prompt for CI; logs `uninstallForceSkip` |
| Bootstrap installer always re-clones (v0.35.0) | ✅ Done | `install.ps1` + `install.sh` remove existing folder, re-clone fresh; CODE RED file-path errors |
| `-Version` / `--version` flag for installers (v0.36.0) | ✅ Done | Probes latest, prints `[VERSION]` `[SCAN]` `[FOUND]`/`[OK]` `[RESOLVED]`, exits without cloning |
| Bumped probe range default 20 → 30 | ✅ Done | `install.ps1`, `install.sh`, `spec/install-bootstrap/readme.md` |
| Resolved merge conflicts in `version.json` + `changelog.md` | ✅ Done | Picked v0.36.0; merged both v0.34.0 entries (search + uninstall) |
| Created `.lovable/pending-issues/` folder | ✅ Done | Required by write-memory protocol |
| Added `02-write-prompt.md` + updated `prompt.md` index | ✅ Done | Trigger words: "write memory", "end memory", "update memory" |

## 🔄 In Progress

_None._

## ⏳ Pending

| Task | Priority | Notes |
|------|----------|-------|
| Verify `-Version` flag end-to-end on real shell | Medium | Needs Windows + Linux smoke test |
| Verify auto-discovery redirect with a real `vN+1` repo | Medium | Spec says fail-fast; only test path is creating a sibling repo |
| Update changelog v0.26.0 entry to include speed filter | Low | Speed filter shipped after v0.26.0 bump (carryover from v0.27.0 plan) |
| Verify 4-filter chain re-indexing end-to-end | Low | Carryover; user wanted manual run-through |
| Verify catalog column alignment with Speed column | Low | Carryover |

## 🚫 Blocked / Avoid

| Item | Reason |
|------|--------|
| Refactor `spec/install-bootstrap/readme.md` into 5 sub-files | User did not approve the split suggestion (offered, not requested). Keep as single file. |
| Touch `.gitmap/release/` folder | Hard rule from `strictly-avoid.md` #7 |

## Architecture Snapshot

- **Bootstrap chain:** `install.{ps1,sh}` → parse current `-vN` → parallel HEAD probe v(N+1)..v(N+30) → redirect to highest, or proceed → wipe `$HOME/scripts-fixer` → fresh `git clone` → `run.ps1`
- **Bootstrap flags:** `-NoUpgrade` / `--no-upgrade`, `-Version` / `--version`, env: `SCRIPTS_FIXER_NO_UPGRADE`, `SCRIPTS_FIXER_PROBE_MAX`, `SCRIPTS_FIXER_REDIRECTED`
- **Models orchestrator:** `scripts/models/run.ps1` → `picker.ps1` (interactive backend select) | `ollama-search.ps1` (live Hub search) | `uninstall.ps1` (multi-backend remove)
- **Env-var handoff:** `LLAMA_CPP_INSTALL_IDS` (CSV) → script 43 ; `OLLAMA_PULL_MODELS` (CSV) → script 42
- **Filter chain (model-picker):** RAM → Size → Speed → Capability → display
