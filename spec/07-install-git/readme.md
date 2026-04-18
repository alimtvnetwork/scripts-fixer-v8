# Spec: Script 07 -- Install Git, Git LFS, and GitHub CLI

## Purpose

Install Git, Git LFS, and GitHub CLI (gh) via Chocolatey and configure global
git settings including user identity, default branch, credential manager,
line endings, editor, and push behavior.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install Git + Git LFS + gh CLI + configure settings (default) |
| `install` | Install/upgrade Git, Git LFS, and GitHub CLI only |
| `configure` | Configure global git settings only |
| `-Help` | Show usage information |

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `chocoPackageName` | string | Chocolatey package (`git`) |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `gitLfs.enabled` | bool | Install Git LFS |
| `gitLfs.chocoPackageName` | string | Chocolatey package (`git-lfs`) |
| `gitLfs.alwaysUpgradeToLatest` | bool | Upgrade LFS on every run |
| `githubCli.enabled` | bool | Install GitHub CLI |
| `githubCli.chocoPackageName` | string | Chocolatey package (`gh`) |
| `githubCli.promptLogin` | bool | Run `gh auth login` if not authenticated |
| `gitConfig.userName` | object | user.name (json-or-prompt mode) |
| `gitConfig.userEmail` | object | user.email (json-or-prompt mode) |
| `gitConfig.defaultBranch` | object | init.defaultBranch (default: main) |
| `gitConfig.credentialManager` | object | credential.helper config |
| `gitConfig.lineEndings` | object | core.autocrlf config |
| `gitConfig.editor` | object | core.editor (default: code --wait) |
| `gitConfig.pushAutoSetupRemote` | object | push.autoSetupRemote toggle |
| `path.updateUserPath` | bool | Add git bin to PATH |

## Flow

1. Assert admin + Chocolatey
2. Install/upgrade Git via Chocolatey
3. Install/upgrade Git LFS via Chocolatey
4. Run `git lfs install` to initialize LFS hooks
5. Install/upgrade GitHub CLI via Chocolatey
6. If not authenticated: run `gh auth login` interactively
7. Configure user.name + user.email (from config or prompt)
8. Set init.defaultBranch to `main`
9. Set credential.helper to `manager`
10. Set core.autocrlf to `true`
11. Set core.editor to `code --wait`
12. Set push.autoSetupRemote to `true`
13. Ensure git bin is in PATH
14. Save resolved state (versions, configs, gh user)

## Install Keywords

| Keyword |
|---------|
| `git` |
| `git-lfs` |
| `gitlfs` |
| `gh` |
| `github-cli` |
| `githubcli` |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `git+desktop` | 7, 8 |
| `git+gh` | 7, 8 |
| `web-dev` | 1, 3, 4, 7, 11 |
| `webdev` | 1, 3, 4, 7, 11 |
| `full-stack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `fullstack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `essentials` | 1, 2, 3, 7, 11 |

```powershell
.\run.ps1 install git
.\run.ps1 install git+desktop
```
