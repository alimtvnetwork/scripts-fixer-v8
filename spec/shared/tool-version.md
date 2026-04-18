# Spec: Shared Assert-ToolVersion Helper

## Purpose

Extract the repeated pattern of "run `--version`, guard empty, check
tracking, return result" into a reusable shared helper. Reduces
boilerplate across all 30+ install helpers and prevents future
empty-version bugs.

## Location

`scripts/shared/tool-version.ps1` -- auto-loaded by `logging.ps1`.

## Functions

### Assert-ToolVersion

```powershell
$result = Assert-ToolVersion -Name "python" -Command "python"
$result = Assert-ToolVersion -Name "nodejs" -Command "node" -ParseScript {
    param($raw) ($raw -replace 'v', '').Trim()
}
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Name` | string | Yes | Tracking name for .installed/ |
| `-Command` | string | Yes | Executable to run |
| `-VersionFlag` | string | No | Flag to get version (default: `--version`) |
| `-ParseScript` | scriptblock | No | Custom parser for raw output |

#### Returns

| Property | Type | Description |
|----------|------|-------------|
| `Exists` | bool | Whether command was found in PATH |
| `Version` | string | Cleaned version string (or `$null`) |
| `HasVersion` | bool | Whether a non-empty version was detected |
| `IsTracked` | bool | Whether this exact version is already in .installed/ |
| `Raw` | string | Raw output from the version command |

### Refresh-EnvPath

```powershell
Refresh-EnvPath
```

Refreshes `$env:Path` from Machine + User registry values. Call after
installs/upgrades so newly installed tools are discoverable.

## Usage Pattern

Before (repeated in every helper):
```powershell
$existing = Get-Command python -ErrorAction SilentlyContinue
if ($existing) {
    $currentVersion = try { & python --version 2>$null } catch { $null }
    $hasVersion = -not [string]::IsNullOrWhiteSpace($currentVersion)
    if ($hasVersion) {
        $isAlreadyTracked = Test-AlreadyInstalled -Name "python" -CurrentVersion $currentVersion
        if ($isAlreadyTracked) {
            Write-Log "Already installed: $currentVersion" -Level "info"
            return
        }
    }
}
```

After (one line):
```powershell
$result = Assert-ToolVersion -Name "python" -Command "python"
if ($result.IsTracked) {
    Write-Log "Already installed: $($result.Version)" -Level "info"
    return
}
```
