# Issues Log -- VS Code Context Menu Fix

## Issue 1: Registry writes fail with `-LiteralPath` error

**Error:**
```
[ FAIL ] FAILED: A parameter cannot be found that matches parameter name 'LiteralPath'.
```

**Root cause:**
The script used PowerShell's `New-Item -LiteralPath` to create registry keys under `HKCR:\*\shell\VSCode`. On Windows PowerShell 5.1, `New-Item` for the Registry provider does **not** support `-LiteralPath` -- only `-Path`. However, `-Path` treats `*` as a wildcard, so the key `HKCR:\*\shell\VSCode` would fail or match unintended locations.

This is a known limitation of Windows PowerShell 5.1's Registry provider. PowerShell 7+ supports `-LiteralPath` on `New-Item`, but the script must support 5.1 since that ships with Windows.

**Fix:**
Replaced all PowerShell registry cmdlets (`New-Item`, `Set-ItemProperty`) with native `reg.exe` calls. `reg.exe` has no wildcard interpretation issues and works identically on all Windows versions:

```powershell
# Before (broken on PS 5.1)
New-Item -LiteralPath $RegistryPath -Force
Set-ItemProperty -LiteralPath $RegistryPath -Name "(Default)" -Value $Label

# After (works everywhere)
reg.exe add "HKCR\*\shell\VSCode" /ve /d "Open with Code" /f
reg.exe add "HKCR\*\shell\VSCode" /v "Icon" /d "C:\...\Code.exe" /f
reg.exe add "HKCR\*\shell\VSCode\command" /ve /d "C:\...\Code.exe \"%1\"" /f
```

A helper `ConvertTo-RegPath` translates the `Registry::HKEY_CLASSES_ROOT\...` paths from config into the short `HKCR\...` format that `reg.exe` expects.

**How to write better code:**
- Always test against Windows PowerShell 5.1 when targeting Windows desktops -- it is still the default shell.
- Prefer `reg.exe` for HKCR writes. It is simpler, has no wildcard quirks, and produces clearer error messages.
- Document the minimum PowerShell version in the script header so future contributors know the constraint.

---

## Issue 2: Detected VS Code path not persisted to config.json

**Symptom:**
The script detected VS Code at `C:\Program Files\Microsoft VS Code\Code.exe` (system install) after the preferred user-install path was not found, but this resolved path was never saved. On every run the detection logic repeated from scratch.

**Root cause:**
The `Invoke-Edition` function resolved the executable path but never wrote it back anywhere. There was no persistence mechanism -- the resolved path lived only in memory for the current run.

**Original fix (v3.0):**
Added a `Save-ResolvedPath` function that wrote a `"resolved"` key back into `config.json`. This worked but violated separation of concerns -- the script was mutating its own declarative config with runtime state.

**Improved fix (v3.1):**
Moved runtime-resolved data out of `config.json` entirely into a repo-root `.resolved/` folder (gitignored). Each script writes to `.resolved/<script-folder>/resolved.json`:

```json
// .resolved/01-vscode-context-menu-fix/resolved.json
{
  "stable": {
    "resolvedExe": "C:\\Program Files\\Microsoft VS Code\\Code.exe",
    "resolvedAt": "2026-04-03T18:10:02+08:00",
    "resolvedBy": "alim"
  }
}
```

A shared helper `scripts/shared/resolved.ps1` provides `Save-ResolvedData` and `Get-ResolvedDir`, merging new keys into existing resolved data.

**How to write better code:**
- Never mutate source config files with runtime-discovered state. Keep config declarative and gitignored runtime state separate.
- Use a dedicated `.resolved/` (or `.cache/`, `.state/`) folder for any data the script discovers at runtime.
- Shared helpers reduce duplication -- `Save-ResolvedData` is used by both script 01 and 02.

---

## Issue 3: `reg.exe add` command subkey fails with "Invalid syntax"

**Error:**
```
[ FAIL ]   FAILED: ERROR: Invalid syntax.
```

**Root cause:**
The command value (e.g. `"C:\...\Code.exe" "%1"` or `"C:\...\pwsh.exe" -NoExit -Command "Set-Location '%V'"`) contains embedded double quotes and `%` characters. Both `reg.exe` direct calls and `cmd.exe /c` wrappers fail because PowerShell's argument splitting and cmd.exe's own quote parsing break on nested quotes.

**Fix (final):**
Replaced all `reg.exe` calls with .NET `[Microsoft.Win32.Registry]` API, which takes string values directly with zero quoting issues:

```powershell
# Before (broken -- reg.exe cannot handle nested quotes)
$out = reg.exe add $cmdRegPath /ve /d $CommandArg /f 2>&1

# After (works -- .NET API, no shell parsing at all)
$subKeyPath = $RegistryPath -replace '^Registry::HKEY_CLASSES_ROOT\\', ''
$hkcr = [Microsoft.Win32.Registry]::ClassesRoot
$cmdKey = $hkcr.CreateSubKey("$subKeyPath\command")
$cmdKey.SetValue("", $CommandArg)
$cmdKey.Close()
```

Applied to both script 10 (VS Code context menu) and script 31 (PowerShell context menu).

**How to write better code:**
- For registry writes with complex string values, prefer .NET `[Microsoft.Win32.Registry]` over `reg.exe` -- it avoids all quoting/escaping issues.
- Reserve `reg.exe` only for simple values without embedded quotes or `%` variables.

---

## Issue 4: "No valid VS Code executable found" after Chocolatey install

**Error:**
```json
{
    "message": "File exists at path: False",
    "level": "fail"
},
{
    "message": "No valid VS Code executable found for either type",
    "level": "fail"
}
```

**Root cause:**
`Resolve-VsCodePath` only checked two hardcoded paths from `config.json`:

1. **User install:** `%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe`
2. **System install:** `C:\Program Files\Microsoft VS Code\Code.exe`

When VS Code was installed via **Chocolatey** (script 01), the executable may not exist at either of these paths. Chocolatey can install VS Code to its own `chocolatey\lib\` directory or create shims in `chocolatey\bin\`. In this scenario, both config paths returned `False` and the script failed immediately with no further detection.

**Why it happened:**
- Script 01 installs VS Code via `choco install vscode`, which may place the executable at a Chocolatey-managed location.
- The config.json paths only cover the standard Microsoft installer locations (user-install via `.exe` installer, or system-wide via admin MSI).
- There was no fallback detection after the two config paths failed.

**Fix:**
Added a 4-tier fallback chain in `Resolve-VsCodePath`:

```
1. .resolved/ cache          (instant, if previous run found it)
2. Config paths (user/system) (standard Microsoft installer locations)
3. Chocolatey paths           (shim in choco\bin\, or exe in choco\lib\)
4. Get-Command / where.exe    (PATH-based discovery as last resort)
```

```powershell
# Chocolatey shim detection
$chocoShimDir = Join-Path $env:ProgramData "chocolatey\bin"
$chocoShimExe = Join-Path $chocoShimDir "Code.exe"
if (Test-Path $chocoShimExe) { return $chocoShimExe }

# Chocolatey lib recursive search
$chocoLibDir = Join-Path $env:ProgramData "chocolatey\lib\vscode"
$foundExe = Get-ChildItem -Path $chocoLibDir -Filter "Code.exe" -Recurse | Select-Object -First 1
if ($foundExe) { return $foundExe.FullName }

# PATH-based discovery
$cmdResult = Get-Command "code" -ErrorAction SilentlyContinue
if ($cmdResult) { return $cmdResult.Source }
```

Once found, the resolved path is cached in `.resolved/10-vscode-context-menu-fix/resolved.json` so subsequent runs skip detection entirely.

**How to write better code:**
- Never rely on only hardcoded paths for tools that can be installed by multiple methods (MSI, user installer, Chocolatey, winget, scoop).
- Build a fallback chain: config paths -> package manager paths -> PATH discovery -> give up.
- Cache the first successful result so detection is instant on repeat runs.
