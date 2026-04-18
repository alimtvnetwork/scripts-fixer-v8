# Spec: Script 09 -- Install C++ (MinGW-w64)

## Purpose

Install a C++ compiler toolchain (MinGW-w64) via Chocolatey and configure
PATH so `g++`, `gcc`, and `make` are available system-wide. Installs into
the project's dev directory when available.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install MinGW + configure PATH (default) |
| `install` | Install/upgrade MinGW only |
| `configure` | Ensure PATH contains MinGW bin only |
| `-Help` | Show usage information |

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `chocoPackageName` | string | Chocolatey package (default: `mingw`) |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `installDir` | object | Install directory resolution (mode, default, override) |
| `path.updateUserPath` | bool | Add MinGW bin to user PATH |
| `verifyCommands` | array | Commands to verify after install (e.g. `g++`, `gcc`, `mingw32-make`) |

## Flow

1. Assert admin + Chocolatey
2. Resolve install directory from config or `$env:DEV_DIR`
3. Install/upgrade MinGW-w64 via Chocolatey (with `--install-directory` if configured)
4. Refresh PATH in current session
5. Verify `g++`, `gcc`, and `mingw32-make` are reachable
6. Add MinGW bin directory to user PATH if configured
7. Print compiler version
8. Save resolved state (version, install dir, timestamp)

## Chocolatey Package

The `mingw` Chocolatey package installs MinGW-w64 which includes:
- `g++.exe` -- C++ compiler
- `gcc.exe` -- C compiler
- `mingw32-make.exe` -- GNU Make for Windows
- `gdb.exe` -- GNU Debugger

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| MinGW-w64 via Chocolatey | Most reliable Windows C++ toolchain; avoids MSVC dependency |
| Verify multiple commands | Ensures full toolchain is functional, not just the package installed |
| Optional install directory | Keeps tools in the dev directory alongside Go, Node, etc. |
| Session PATH refresh | User can compile immediately without opening a new terminal |

## Install Keywords

| Keyword |
|---------|
| `cpp` |
| `c++` |
| `mingw` |
| `gcc` |

**Group shortcuts** (installs multiple scripts):

| Keyword | Scripts |
|---------|---------|
| `full-stack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |
| `fullstack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16 |

```powershell
.\run.ps1 install cpp
.\run.ps1 install full-stack
```
