# Spec: Script 03 -- Install Node.js

## Purpose

Install Node.js (LTS) via Chocolatey and configure the npm global prefix
to reside inside the shared dev directory, keeping global packages organised.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install Node.js + configure npm (default) |
| `install` | Install/upgrade Node.js only |
| `configure` | Configure npm prefix and PATH only |
| `-Help` | Show usage information |

## File Structure

```
scripts/03-install-nodejs/
  config.json
  log-messages.json
  run.ps1
  helpers/
    nodejs.ps1
```

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `chocoPackageName` | string | Chocolatey package name (`nodejs-lts`) |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `devDirSubfolder` | string | Subfolder under dev dir (`nodejs`) |
| `npm.setGlobalPrefix` | bool | Whether to set npm prefix |
| `npm.globalPrefix` | string | Fallback prefix path |
| `path.updateUserPath` | bool | Add npm bin to User PATH |
| `path.ensureNpmBinInPath` | bool | Also add node_modules/.bin |

## Flow

1. Parse subcommand (default: `all`)
2. Assert admin privileges
3. Assert Chocolatey is available
4. Install/upgrade Node.js via Chocolatey
5. Configure `npm config set prefix` to dev dir subfolder
6. Add prefix dir to User PATH (with dedup)
7. Save resolved state (node version, npm version, prefix path)

## Dependencies

- Shared: `logging.ps1`, `resolved.ps1`, `git-pull.ps1`, `help.ps1`,
  `choco-utils.ps1`, `path-utils.ps1`, `dev-dir.ps1`
- Requires: Administrator privileges, Chocolatey

## Install Keywords

| Keyword |
|---------|
| `nodejs` |
| `node` |
| `node.js` |
| `yarn` |
| `bun` |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `pnpm` | 3, 4 |
| `node+pnpm` | 3, 4 |
| `web-dev` | 1, 3, 4, 7, 11 |
| `webdev` | 1, 3, 4, 7, 11 |
| `full-stack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `fullstack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `frontend` | 1, 3, 4, 11 |
| `essentials` | 1, 2, 3, 7, 11 |

```powershell
.\run.ps1 install nodejs
.\run.ps1 install pnpm
```
