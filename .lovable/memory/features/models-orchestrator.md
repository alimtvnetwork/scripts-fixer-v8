---
name: Models orchestrator
description: scripts/models/ unifies llama.cpp + Ollama under one entry point with search, install, uninstall subcommands
type: feature
---

# Models Orchestrator (`scripts/models/`)

## Entry Points

| Command | Effect |
|---------|--------|
| `.\run.ps1 models` | Interactive: prompt for backend → existing picker |
| `.\run.ps1 models <csv>` | Direct install: e.g. `models qwen2.5-coder-3b,llama3.2,deepseek-r1:8b` |
| `.\run.ps1 models -Backend llama` / `ollama` | Skip backend prompt |
| `.\run.ps1 models list [llama\|ollama]` | Browse catalog without installing |
| `.\run.ps1 models search <query>` | Live search ollama.com/search?q=… |
| `.\run.ps1 models uninstall [llama\|ollama] [-Force]` | Multi-backend removal with confirm |

Aliases for `models`: `model`, `-M`. Aliases for `uninstall`: `remove`, `rm`.

## File Layout

```
scripts/models/
├── run.ps1                       # Thin dispatcher (~120 lines)
├── config.json
├── log-messages.json
└── helpers/
    ├── picker.ps1                # Backend selection, CSV id resolution, dispatch
    ├── ollama-search.ps1         # Hub search (HTTP GET + x-test-* regex parser)
    └── uninstall.ps1             # Get-InstalledLlamaCppModels, Get-InstalledOllamaModels, Show/Read/Confirm/Invoke
```

## Env-Var Handoff Contract

| Var | Read by | Format |
|-----|---------|--------|
| `LLAMA_CPP_INSTALL_IDS` | `scripts/43-install-llama-cpp/run.ps1` | CSV of catalog ids; bypasses RAM/Size/Speed/Capability filter prompts |
| `OLLAMA_PULL_MODELS` | `scripts/42-install-ollama/run.ps1` | CSV of slugs; resolves against `defaultModels` first, falls back to ad-hoc `ollama pull <slug>` |

## Uninstall Sources

- **llama.cpp:** scans `.installed/model-*.json`, cross-references `43-install-llama-cpp/models-catalog.json`, resolves GGUF folder from `.resolved/43-install-llama-cpp.json` (fallback `$env:DEV_DIR/llama-models`), removes file + tracking record
- **Ollama:** `ollama list` → parse columns → `ollama rm <id>`. Gracefully handles missing daemon/binary (never throws)

## `-Force` Flag

`models uninstall -Force` skips the final yes/no gate. Selection step unchanged. Logs `-Force flag set: skipping confirmation prompt.` (level `warn`).

## Spec

`spec/models/readme.md` — algorithm, file layout, dispatcher contract, "how to add a third backend" section.
