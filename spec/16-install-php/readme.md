# Spec: Script 16 -- Install PHP (+ phpMyAdmin)

## Purpose

Install PHP and/or phpMyAdmin via Chocolatey. Supports three modes.

## Naming Convention

| Shortcut Label | Meaning | Keyword |
|----------------|---------|---------|
| **PHP + phpMyAdmin** | Install PHP and phpMyAdmin | `php`, `php+phpmyadmin` |
| **PHP only** | Install PHP without phpMyAdmin | `php-only` |
| **phpMyAdmin only** | Install phpMyAdmin without PHP | `phpmyadmin`, `phpmyadmin-only` |

## File Structure

```
scripts/16-install-php/
├── config.json              # Package names, modes, verify command
├── log-messages.json        # Display strings
├── run.ps1                  # Entry point (accepts -Mode param)
├── helpers/
│   └── php.ps1              # Install-Php + Install-PhpMyAdmin functions
└── logs/                    # Auto-created (gitignored)
```

## Usage

```powershell
.\run.ps1 install php                # PHP + phpMyAdmin (default)
.\run.ps1 install php+phpmyadmin     # PHP + phpMyAdmin (explicit)
.\run.ps1 install php-only           # PHP only
.\run.ps1 install phpmyadmin         # phpMyAdmin only
.\run.ps1 -I 16                      # PHP + phpMyAdmin (default mode)
.\run.ps1 -I 16 -- -Mode php-only   # PHP only
.\run.ps1 -I 16 -- -Mode phpmyadmin-only  # phpMyAdmin only
```

## Modes

### php+phpmyadmin (default)

1. Install PHP via Chocolatey (if not already installed)
2. Verify PHP installation
3. Install phpMyAdmin via Chocolatey (if not already installed)

### php-only

1. Install PHP via Chocolatey (if not already installed)
2. Verify PHP installation
3. Skip phpMyAdmin

### phpmyadmin-only

1. Skip PHP installation
2. Install phpMyAdmin via Chocolatey (if not already installed)

## Mode Resolution Order

1. `-Mode` parameter on `run.ps1` (highest priority)
2. `$env:PHP_MODE` environment variable (set by keyword resolver)
3. Default: `php+phpmyadmin`

## Config (`config.json`)

| Key | Type | Purpose |
|-----|------|---------|
| `php.enabled` | bool | Toggle PHP install |
| `php.chocoPackage` | string | Chocolatey package name (`php`) |
| `php.verifyCommand` | string | Command to verify PHP (`php`) |
| `phpmyadmin.enabled` | bool | Toggle phpMyAdmin install |
| `phpmyadmin.chocoPackage` | string | Chocolatey package name (`phpmyadmin`) |
| `defaultMode` | string | Default mode when not specified |

## Execution Flow

1. If `-Help`: display usage and exit
2. Load shared + script helpers
3. Git pull (unless `$env:SCRIPTS_ROOT_RUN`)
4. Assert admin privileges
5. Announce mode
6. Install PHP (unless phpmyadmin-only)
7. Install phpMyAdmin (unless php-only)
8. Save resolved data and install records

## Log Messages

Defined in `log-messages.json`. Key messages:
- `pmaChecking` / `pmaFound` -- phpMyAdmin detection
- `pmaInstalling` / `pmaInstallSuccess` -- install progress
- `pmaInstallFailed` -- failure with CODE RED path logging
- `pmaSkipped` -- shown in php-only mode

## Helpers

| File | Function | Purpose |
|------|----------|---------|
| `php.ps1` | `Install-Php` | Install PHP via Chocolatey, verify, track |
| `php.ps1` | `Install-PhpMyAdmin` | Install phpMyAdmin via Chocolatey, track |

## Install Keywords

| Keyword | Mode |
|---------|------|
| `php` | php+phpmyadmin |
| `phpmyadmin` | phpmyadmin-only |
| `php+phpmyadmin` | php+phpmyadmin |
| `php-only` | php-only |
| `phpmyadmin-only` | phpmyadmin-only |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `full-stack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `fullstack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `backend` | 5, 6, 16, 20 |

```powershell
.\run.ps1 install php
.\run.ps1 install full-stack
```
