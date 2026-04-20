<# Bucket E: teams -- Microsoft Teams cache (NOT chats, NOT login, NOT calendar) #>
param([switch]$DryRun, [switch]$Yes, [int]$Days = 30, [hashtable]$SharedResult)

$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $here "_sweep.ps1")

$result = New-CleanResult -Category "teams" -Label "Teams cache (chats + login SAFE)" -Bucket "E"

$appdata = Get-AppDataPath
$local   = Get-LocalAppDataPath
if ([string]::IsNullOrWhiteSpace($appdata) -or [string]::IsNullOrWhiteSpace($local)) {
    $result.Notes += "APPDATA / LOCALAPPDATA not set"
    Set-CleanResultStatus -Result $result -DryRun:$DryRun
    return $result
}

# Two distinct Teams installs coexist on most machines:
#   1. CLASSIC Teams (Electron, deprecated) -> %APPDATA%\Microsoft\Teams
#   2. NEW Teams (WebView2, MS Store)       -> %LOCALAPPDATA%\Packages\MSTeams_*\LocalCache\Microsoft\MSTeams
$classicRoot = Join-Path $appdata "Microsoft\Teams"

$newTeamsRoots = @()
$packagesDir = Join-Path $local "Packages"
if (Test-Path -LiteralPath $packagesDir) {
    try {
        $matches = Get-ChildItem -LiteralPath $packagesDir -Directory -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -like "MSTeams_*" -or $_.Name -like "*MicrosoftTeams*" }
        foreach ($m in $matches) {
            foreach ($leaf in @("LocalCache\Microsoft\MSTeams", "LocalCache\Microsoft\Teams")) {
                $p = Join-Path $m.FullName $leaf
                if (Test-Path -LiteralPath $p) { $newTeamsRoots += $p }
            }
        }
    } catch {
        Write-Log "teams new-store enumerate failed: $($_.Exception.Message)" -Level "warn"
    }
}

# CLASSIC Teams cache-only subpaths -- EXCLUDES:
#   - Cookies, Local Storage, IndexedDB  (auth tokens + cached chat)
#   - Backgrounds                         (user uploads)
#   - storage.json, settings.json         (account state)
$classicCacheSubs = @(
    "Cache",
    "Code Cache",
    "GPUCache",
    "blob_storage",
    "tmp",
    "Service Worker\CacheStorage",
    "Service Worker\ScriptCache",
    "Application Cache"
)

# NEW Teams cache-only subpaths
$newCacheSubs = @(
    "EBWebView\Default\Cache",
    "EBWebView\Default\Code Cache",
    "EBWebView\Default\GPUCache",
    "EBWebView\Default\Service Worker\CacheStorage",
    "EBWebView\Default\Service Worker\ScriptCache",
    "Logs"
)

$anyFound = $false

if (Test-Path -LiteralPath $classicRoot) {
    $anyFound = $true
    foreach ($sub in $classicCacheSubs) {
        $p = Join-Path $classicRoot $sub
        if (Test-Path -LiteralPath $p) {
            Invoke-PathSweep -Path $p -Result $result -DryRun:$DryRun -LogPrefix "teams-classic/$sub"
        }
    }
}

foreach ($root in $newTeamsRoots) {
    $anyFound = $true
    foreach ($sub in $newCacheSubs) {
        $p = Join-Path $root $sub
        if (Test-Path -LiteralPath $p) {
            Invoke-PathSweep -Path $p -Result $result -DryRun:$DryRun -LogPrefix "teams-new/$sub"
        }
    }
}

if (-not $anyFound) {
    $result.Notes += "Microsoft Teams not installed (neither classic nor new)"
}

Set-CleanResultStatus -Result $result -DryRun:$DryRun
return $result
