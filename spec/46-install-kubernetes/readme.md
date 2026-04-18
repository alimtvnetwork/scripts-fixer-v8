# Spec: Script 46 -- Install Kubernetes Tools

## Purpose

Install kubectl, minikube, and Helm via Chocolatey for local Kubernetes
development. Optionally installs Lens Kubernetes IDE.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install kubectl + minikube + Helm + PATH (default) |
| `install` | Install/upgrade all enabled tools |
| `uninstall` | Uninstall completely via Chocolatey |
| `-Help` | Show usage information |

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `kubectl.enabled` | bool | Install kubectl |
| `kubectl.chocoPackageName` | string | `kubernetes-cli` |
| `kubectl.alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `minikube.enabled` | bool | Install minikube |
| `minikube.chocoPackageName` | string | `minikube` |
| `minikube.alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `helm.enabled` | bool | Install Helm |
| `helm.chocoPackageName` | string | `kubernetes-helm` |
| `helm.alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `lens.enabled` | bool | Install Lens IDE (disabled by default) |
| `path.updateUserPath` | bool | Add tools to PATH |

## Flow

1. Assert admin + Chocolatey
2. Install/upgrade kubectl via Chocolatey
3. Install/upgrade minikube via Chocolatey
4. Install/upgrade Helm via Chocolatey
5. Optionally install Lens IDE
6. Ensure all tool directories in PATH
7. Save resolved state (kubectl, minikube, helm versions)

## Install Keywords

| Keyword |
|---------|
| `kubernetes` |
| `kubectl` |
| `k8s` |
| `minikube` |
| `helm` |

**Group shortcuts**:

| Keyword | Scripts |
|---------|---------|
| `devops` | 7, 45, 46 |
| `container-dev` | 45, 46 |

## Dependencies

- Shared: `logging.ps1`, `resolved.ps1`, `git-pull.ps1`, `help.ps1`,
  `choco-utils.ps1`, `path-utils.ps1`, `installed.ps1`
- Requires: Administrator privileges, internet access
