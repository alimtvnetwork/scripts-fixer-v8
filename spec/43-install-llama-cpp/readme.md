# Script 43 -- Install llama.cpp

## Purpose
Downloads llama.cpp pre-built binaries (CUDA, AVX2 CPU, KoboldCPP), extracts them to the dev directory, adds binary folders to user PATH, and provides an **interactive model picker** for downloading from an 81-model catalog via aria2c accelerated downloads.

## Directory Structure
```
scripts/43-install-llama-cpp/
  config.json           # Executable variants, aria2c config, paths
  models-catalog.json   # 81-model catalog with rich metadata (separate file)
  log-messages.json     # All log message templates
  run.ps1               # Entry point (param: Command, Path, -Help)
  helpers/
    llama-cpp.ps1       # Install-LlamaCppExecutables, Uninstall-LlamaCpp
    model-picker.ps1    # Show-ModelCatalog, Read-RamFilter, Read-SizeFilter, Read-SpeedFilter, Read-CapabilityFilter, Read-ModelSelection, Install-SelectedModels, Invoke-ModelInstaller
```

## Install Flow

### Pre-flight Checks
1. **Hardware detection** -- `Get-HardwareProfile` detects CUDA GPU (nvidia-smi, nvcc, WMI) and AVX2 CPU support (WMI + heuristic). Incompatible executable variants are skipped with clear logging.
2. **URL freshness** -- HEAD-checks executable download URLs; blocks if stale
3. **Disk space** -- blocks if insufficient space for executables

### Executables
1. Each variant in `config.executables` has a `requires` field (`"cuda"`, `"avx2"`, or `""`)
2. Variants whose `requires` hardware is not detected are skipped
3. Compatible variants: download, extract, verify, add to PATH
4. ZIP integrity validation (magic bytes + expected size)

### Interactive Model Picker
1. **aria2c setup** -- auto-installs via `choco install aria2`; falls back to `Invoke-DownloadWithRetry`
2. **Models directory** -- user picks custom path or Enter for default (`<dev-dir>\llama-models`)
3. **RAM filter** -- optional filter by available system RAM:
   - Preset tiers: 4, 8, 16, 32, 64 GB or auto-detected system RAM
   - Direct numeric input supported; Enter to skip
4. **Size filter** -- optional filter by download size tier:
   - `[1] Tiny (<1 GB)`, `[2] Small (<3 GB)`, `[3] Medium (<6 GB)`, `[4] Large (<12 GB)`, `[5] XLarge (12+ GB)`
   - Enter to skip; models re-indexed after filtering
5. **Speed filter** -- optional filter by inference speed tier:
   - `[1] Instant (<1 GB)`, `[2] Fast (<3 GB)`, `[3] Moderate (<8 GB)`, `[4] Slow (8+ GB)`
   - Supports multi-select (e.g. "1,2"); Enter to skip; models re-indexed after filtering
6. **Capability filter** -- optional filter menu before catalog display:
   - `[1] Coding`, `[2] Reasoning`, `[3] Writing`, `[4] Chat`, `[5] Voice`, `[6] Multilingual`
   - Supports same selection syntax as model picker (single, range, comma-separated)
   - Enter to skip filter and show all models; OR logic (any matching cap shown)
   - Models re-indexed after filtering for clean numbered display
6. **Catalog display** -- numbered list with columns: #, Model, Params, Quant, Size, RAM, Capabilities
   - Starred (recommended) models shown first, color-coded by rating
7. **Selection input** -- supports:
   - Single: `3`
   - Range: `1-5`
   - Mixed: `1-3,7,12-15`
   - All: `all`
   - Quit: `q`
8. **Disk space check** -- warns if insufficient for selected models
9. **Download** -- each model via aria2c (16 connections), tracked in `.installed/model-<id>.json`
10. **Summary** -- downloaded/skipped/failed counts

## Model Catalog (`models-catalog.json`)

- **81 models** across coding, reasoning, writing, voice, and general categories
- No hardcoded paths -- models directory resolved at runtime
- Rich metadata per model: `displayName`, `family`, `parameters`, `quantization`, `fileSizeGB`, `ramRequiredGB`, `ramRecommendedGB`, capability flags, `rating`, `bestFor`, `notes`, `license`, `downloadUrl`, `sha256`
- SHA256 checksums for download integrity verification (empty = skip check, populated gradually)
- Includes latest models: Gemma 3 (1B/4B/12B), Llama 3.2 (1B/3B), SmolLM2, Phi-4 Mini/14B, Granite 3.1, Qwen 3/3.5, Claude distills, Devstral, EXAONE 4.0, Whisper variants

## Commands

| Command       | Description                                          |
|---------------|------------------------------------------------------|
| `all`         | Download executables + interactive model picker       |
| `executables` | Download and extract executables only                 |
| `models`      | Interactive model picker only                         |
| `uninstall`   | Remove binaries, model tracking, clean PATH           |

## Dependencies

- Shared: `logging.ps1`, `resolved.ps1`, `git-pull.ps1`, `help.ps1`,
  `path-utils.ps1`, `dev-dir.ps1`, `installed.ps1`, `download-retry.ps1`,
  `disk-space.ps1`, `url-freshness.ps1`, `aria2c-download.ps1`, `choco-utils.ps1`,
  `hardware-detect.ps1`
- Optional: aria2c (auto-installed via Chocolatey; falls back to Invoke-WebRequest)
- Requires: Administrator privileges, internet access
