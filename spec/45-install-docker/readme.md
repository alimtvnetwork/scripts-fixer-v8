# Spec: Script 45 -- Install Docker Desktop

## Purpose

Install Docker Desktop via Chocolatey with WSL2 backend verification. Includes
Docker Compose v2 (bundled), daemon status checking, and PATH setup.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Check WSL2 + install Docker + verify daemon + PATH (default) |
| `install` | Install/upgrade Docker Desktop only |
| `status` | Check Docker daemon and version status |
| `uninstall` | Uninstall completely via Chocolatey |
| `-Help` | Show usage information |

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `chocoPackageName` | string | Chocolatey package (`docker-desktop`) |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `wsl2.ensureEnabled` | bool | Check WSL2 before install |
| `postInstall.verifyDaemon` | bool | Run `docker info` after install |
| `postInstall.pullHelloWorld` | bool | Pull hello-world image (disabled) |
| `path.updateUserPath` | bool | Add Docker to PATH |

## Flow

1. Assert admin + Chocolatey
2. Check WSL2 status (`wsl --status`)
3. Install/upgrade Docker Desktop via Chocolatey
4. Verify Docker daemon is running (`docker info`)
5. Show Docker Compose version
6. Ensure Docker bin is in PATH
7. Save resolved state (docker, compose versions)
8. Warn about reboot if fresh install

## Install Keywords

| Keyword |
|---------|
| `docker` |
| `docker-desktop` |
| `containers` |

**Group shortcuts**:

| Keyword | Scripts |
|---------|---------|
| `devops` | 7, 45, 46 |
| `container-dev` | 45, 46 |

## Dependencies

- Shared: `logging.ps1`, `resolved.ps1`, `git-pull.ps1`, `help.ps1`,
  `choco-utils.ps1`, `path-utils.ps1`, `installed.ps1`
- Requires: Administrator privileges, internet access, WSL2 (recommended)
