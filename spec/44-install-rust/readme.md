# Spec: Script 44 -- Install Rust

## Purpose

Install the Rust toolchain via rustup (rustup-init.exe), configure components
(clippy, rustfmt, rust-analyzer), optionally add WASM target and cargo packages,
and ensure `~/.cargo/bin` is in the user PATH.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install Rust + components + PATH setup (default) |
| `install` | Install/upgrade Rust toolchain only |
| `components` | Install configured components only |
| `uninstall` | Uninstall via `rustup self uninstall` |
| `-Help` | Show usage information |

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `installMethod` | string | Always `rustup` |
| `rustupUrl` | string | URL for rustup-init.exe |
| `defaultToolchain` | string | Toolchain channel (stable/nightly/beta) |
| `alwaysUpgradeToLatest` | bool | Run `rustup update` on every run |
| `components.clippy` | bool | Install clippy linter |
| `components.rustfmt` | bool | Install code formatter |
| `components.rust-analyzer` | bool | Install LSP server |
| `targets.addWasm` | bool | Add wasm32-unknown-unknown target |
| `cargoPackages.enabled` | bool | Install cargo packages |
| `cargoPackages.packages` | array | List of cargo packages to install |
| `path.updateUserPath` | bool | Add cargo/bin to PATH |

## Flow

1. Assert admin
2. Check if `rustc` exists -- skip or upgrade
3. If missing: download rustup-init.exe, run with `-y --default-toolchain stable`
4. Install components: clippy, rustfmt, rust-analyzer
5. Optionally add WASM target
6. Optionally install cargo packages
7. Ensure `~/.cargo/bin` in PATH
8. Save resolved state (rustc, cargo, rustup versions)

## Install Keywords

| Keyword |
|---------|
| `rust` |
| `rustup` |
| `cargo` |
| `rustlang` |

**Group shortcuts**:

| Keyword | Scripts |
|---------|---------|
| `systems-dev` | 9, 44 |
| `full-stack` | 1, 2, 3, 4, 5, 7, 8, 9, 11, 16, 39, 40, 44 |

## Dependencies

- Shared: `logging.ps1`, `resolved.ps1`, `git-pull.ps1`, `help.ps1`,
  `path-utils.ps1`, `installed.ps1`, `download-retry.ps1`
- Requires: Administrator privileges, internet access
