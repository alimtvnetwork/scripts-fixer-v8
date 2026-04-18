# Spec: Script 06 -- Install Golang

## Overview

Installs Go via Chocolatey and configures GOPATH, PATH, go env settings,
and Go development tools (golangci-lint, go vet).
Adapted from the user's existing `go-install.ps1` to follow project conventions.

---

## File Structure

```
scripts/06-install-golang/
+-- config.json              # Go settings, GOPATH config, go env settings, tools
+-- go-config.sample.json    # Original reference config from user
+-- log-messages.json        # Display strings and banners
+-- run.ps1                  # Thin orchestrator with subcommand routing
+-- helpers/
|   +-- golang.ps1           # All Go-specific logic
+-- logs/                    # Auto-created (gitignored)

.resolved/05-install-golang/
+-- resolved.json            # GOPATH, version, timestamps
```

## Subcommands

```powershell
.\run.ps1                    # Install + configure + tools (default "all")
.\run.ps1 install            # Install/upgrade Go only
.\run.ps1 configure          # Configure GOPATH/env + install tools (skip Go install)
.\run.ps1 -Help              # Show usage
```

## config.json Schema

| Key | Type | Description |
|-----|------|-------------|
| `enabled` | bool | Master enable/disable |
| `chocoPackageName` | string | Chocolatey package name (`golang`) |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `devDirSubfolder` | string | Subfolder under dev dir for GOPATH |
| `gopath.mode` | string | `json-only` or `json-or-prompt` |
| `gopath.default` | string | Default GOPATH if not overridden |
| `gopath.override` | string | Hard override (skips prompt) |
| `path.updateUserPath` | bool | Add GOPATH\bin to user PATH |
| `path.ensureGoBinInPath` | bool | Ensure bin dir is in PATH |
| `goEnv.applyMode` | string | `json-only` or `json-or-prompt` |
| `goEnv.relativeToGopath` | bool | Resolve relativePath entries from GOPATH |
| `goEnv.settings.*` | object | Individual go env settings (GOMODCACHE, etc.) |
| `tools.golangciLint.enabled` | bool | Install golangci-lint via `go install` |
| `tools.golangciLint.installPackage` | string | Full `go install` package path with version |

## GOPATH Resolution Priority

1. `$env:DEV_DIR` + `devDirSubfolder` (set by orchestrator script 04)
2. `gopath.override` from config (if non-empty)
3. User prompt (if mode is `json-or-prompt`)
4. `gopath.default` from config

## Go Tools

### go vet (built-in)

`go vet` is part of the Go toolchain and requires no separate installation.
The script verifies it is available and logs the result.

### golangci-lint

Installed via `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`.
The binary is placed in `GOPATH\bin` which should already be in PATH
(handled by the PATH configuration step).

- Tracked in `.installed/golangci-lint.json`
- Skipped if already installed and version matches tracked record
- Can be disabled via `tools.golangciLint.enabled: false` in config

## Functions (helpers/golang.ps1)

| Function | Purpose |
|----------|---------|
| `Install-Go` | Install/upgrade via Chocolatey |
| `Resolve-Gopath` | Priority-based GOPATH resolution |
| `Initialize-Gopath` | Create directory + set env var |
| `Update-GoPath` | Add GOPATH\bin to user PATH (uses shared `Add-ToUserPath`) |
| `Set-GoEnvSetting` | Run `go env -w KEY=VALUE` with logging |
| `Configure-GoEnv` | Apply all go env settings from config |
| `Install-GoTools` | Install golangci-lint via `go install`, verify go vet |
| `Invoke-GoSetup` | Orchestrate full install + configure + tools flow |

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+**
- **Administrator privileges**
- **Chocolatey** (script 03, or will auto-check via `Assert-Choco`)

## Install Keywords

| Keyword |
|---------|
| `go` |
| `golang` |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `backend` | 5, 6, 16, 20 |

```powershell
.\run.ps1 install go
.\run.ps1 install backend
```
