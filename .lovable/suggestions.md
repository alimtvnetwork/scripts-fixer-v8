# Suggestions

> All improvement ideas — pending and implemented — in one file.

---

## Active Suggestions

### Model catalog auto-update from Hugging Face
- **Status:** Pending
- **Priority:** High
- **Description:** Periodically check Hugging Face trending for new GGUF releases and auto-suggest catalog additions
- **Added:** v0.26.0 cycle

### SHA256 checksums in catalog
- **Status:** Pending
- **Priority:** High
- **Description:** Add SHA256 to `models-catalog.json` and verify after download for integrity
- **Added:** v0.26.0 cycle

### Parallel model downloads via aria2c batch mode
- **Status:** Pending
- **Priority:** High
- **Description:** Use `aria2c -i input.txt` to download multiple selected models concurrently
- **Added:** v0.26.0 cycle

### GUI/TUI interface for model picker
- **Status:** Pending
- **Priority:** Medium
- **Description:** Curses-style or Windows Forms picker as an alternative to the numbered console list
- **Added:** v0.26.0 cycle

### Model benchmarking after download
- **Status:** Pending
- **Priority:** Medium
- **Description:** Run a quick inference test after each model download to verify it loads and responds
- **Added:** v0.26.0 cycle

### Model size estimation from parameter count
- **Status:** Pending
- **Priority:** Medium
- **Description:** When `fileSizeGB` is unknown in the catalog, estimate from parameter count (params × bits / 8)
- **Added:** v0.26.0 cycle

### Export/import model selections as preset files
- **Status:** Pending
- **Priority:** Medium
- **Description:** Save a selection as `presets/coding.json` and reload with `models -Preset coding`
- **Added:** v0.26.0 cycle

### Model catalog web viewer
- **Status:** Pending
- **Priority:** Medium
- **Description:** React page in the project that browses `models-catalog.json` with filters
- **Added:** v0.26.0 cycle

### Cross-machine settings sync via cloud storage
- **Status:** Pending
- **Priority:** Low
- **Description:** Sync `settings/` folder via OneDrive/Dropbox/git for multi-machine consistency
- **Added:** v0.26.0 cycle

### Linux/macOS support for install scripts (not just bootstrap)
- **Status:** Pending
- **Priority:** Low
- **Description:** Bootstrap is cross-platform; the actual installer scripts are still Windows-only
- **Added:** v0.26.0 cycle

### Docker, Rust script additions
- **Status:** Pending
- **Priority:** Low
- **Description:** Already have script slots 44-46 reserved for Rust, Docker, Kubernetes
- **Added:** v0.26.0 cycle

---

## Implemented Suggestions

### Bump probe range default 20 → 30
- **Implemented:** v0.36.0 (2026-04-18)
- **Notes:** Changed `$probeMax = 30` in `install.ps1` and `PROBE_MAX=${SCRIPTS_FIXER_PROBE_MAX:-30}` in `install.sh`. Spec updated. Gives more headroom before manual env-var override needed.

### `-Version` / `--version` diagnostic flag
- **Implemented:** v0.36.0 (2026-04-18)
- **Notes:** Both installers probe latest, log `[VERSION]` `[SCAN]` `[FOUND]`/`[OK]` `[RESOLVED]`, exit without cloning. Useful for "what would I get if I ran this?" debugging. Test case added to spec checklist.

### Always fresh-clone in bootstrap
- **Implemented:** v0.35.0 (2026-04-18)
- **Notes:** Replaced `git pull` with wipe + fresh `git clone`. Eliminates merge conflicts, stale untracked files, drift. CODE RED file-path errors on failure with recovery hint (close terminal / `sudo rm -rf`).

### `models search <query>` — Ollama Hub live search
- **Implemented:** v0.34.0 (2026-04-17)
- **Notes:** `scripts/models/helpers/ollama-search.ps1`. Regex parser anchored on stable `x-test-*` markers. CSV dispatch via existing `OLLAMA_PULL_MODELS` env-var handoff.

### `models uninstall` orchestrator subcommand
- **Implemented:** v0.34.0 (2026-04-17)
- **Notes:** Multi-backend listing, multi-select with `1,3 | 1-5 | all`, yes-confirm, deletes via each backend's natural removal path. `-Force` added in v0.34.1 for CI.

### Install bootstrap auto-discovery
- **Implemented:** v0.31.0 (2026-04-17)
- **Notes:** Spec at `spec/install-bootstrap/readme.md`. Parallel HEAD probes via `Start-ThreadJob` (PS) / `xargs -P 20` (bash). Redirect-loop guard via `SCRIPTS_FIXER_REDIRECTED=1`.

### `scripts/models/` unified orchestrator
- **Implemented:** v0.32.0 (2026-04-17)
- **Notes:** Thin dispatcher delegates to `picker.ps1`. Env-var handoff contract: `LLAMA_CPP_INSTALL_IDS` / `OLLAMA_PULL_MODELS`. Documented in `spec/models/readme.md`.

### Speed-tier column + filter in model picker
- **Implemented:** v0.26.0 (2026-04-16)
- **Notes:** instant/fast/moderate/slow tiers based on `fileSizeGB`. Multi-select. Inserted into 4-filter chain.

### RAM auto-detection filter
- **Implemented:** v0.26.0 (2026-04-16)
- **Notes:** WMI `Get-CimInstance` for system RAM detect, manual tier override available.

---

## Script-Specific Suggestions

See `mem://suggestions/01-suggestions-tracker` for the per-script tracker including completed items.
See `.lovable/memory/suggestions/completed/` for detailed suggestion docs per script.
