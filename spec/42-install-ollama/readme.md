# Script 42 -- Install Ollama

## Purpose
Downloads and installs [Ollama](https://ollama.com) for running local LLMs on Windows. Configures models directory, sets `OLLAMA_MODELS` environment variable, and optionally pulls starter models.

## Directory Structure
```
scripts/42-install-ollama/
  config.json           # Paths, download URL, default models list
  log-messages.json     # All log message templates
  run.ps1               # Entry point (param: Command, Path, -Help)
  helpers/
    ollama.ps1          # Install-Ollama, Configure-OllamaModels, Pull-OllamaModels, Uninstall-Ollama
```

## Install Flow
1. Check if `ollama` is already on PATH
2. Download `OllamaSetup.exe` with retry (3 attempts, exponential backoff via `Invoke-DownloadWithRetry`)
3. Run installer silently (`/VERYSILENT /NORESTART /SUPPRESSMSGBOXES`)
4. Refresh PATH so `ollama` is discoverable
5. Prompt user for models directory (default: `<dev-dir>\ollama-models`)
   - Skipped under orchestrator (`$env:SCRIPTS_ROOT_RUN = "1"`) -- uses default
6. Set `OLLAMA_MODELS` user environment variable
7. Offer to pull default models (Llama 3.2, Qwen 2.5 Coder, DeepSeek R1)
   - Auto-accepted under orchestrator

## Orchestrator Integration

When `$env:SCRIPTS_ROOT_RUN = "1"` (running under Script 12):

- Models directory prompt uses default (no `Read-Host`)
- Model pull confirmations auto-accept all models

## Commands

| Command     | Description                                      |
|-------------|--------------------------------------------------|
| `all`       | Install + configure models dir + pull models     |
| `install`   | Download and install Ollama only                  |
| `models`    | Configure models directory only                   |
| `pull`      | Pull default models (requires Ollama installed)   |
| `uninstall` | Remove Ollama, env vars, tracking                 |

## Install Keywords

| Keyword       | Scripts |
|---------------|---------|
| `ollama`      | 42      |
| `local-llm`   | 42      |
| `llm`         | 42      |
| `ai-tools`    | 42, 43  |
| `local-ai`    | 42, 43  |
| `ai-full`     | 5, 41, 42, 43 |

## Usage
```powershell
.\run.ps1 -I 42                    # Full install + models
.\run.ps1 install ollama           # Via keyword
.\run.ps1 -I 42 -- install        # Install only
.\run.ps1 -I 42 -- models         # Configure models dir only
.\run.ps1 -I 42 -- pull           # Pull models only
.\run.ps1 -I 42 -- uninstall      # Remove everything
```

## Dependencies

- Shared: `logging.ps1`, `resolved.ps1`, `git-pull.ps1`, `help.ps1`,
  `path-utils.ps1`, `dev-dir.ps1`, `installed.ps1`, `download-retry.ps1`,
  `disk-space.ps1`
- Requires: Administrator privileges, internet access

## Environment Variables Set
- `OLLAMA_MODELS` -- Path to models directory (user scope)

## Default Models
| Model | Size | Purpose |
|-------|------|---------|
| Llama 3.2 (3B) | ~2 GB | General |
| Qwen 2.5 Coder (7B) | ~4.7 GB | Coding |
| DeepSeek R1 (8B) | ~4.9 GB | Reasoning |

## Resolved State
Saved to `.resolved/42-install-ollama.json`:
- `ollamaVersion` -- Installed version string
- `modelsDir` -- Configured models directory
- `timestamp` -- ISO 8601 timestamp
