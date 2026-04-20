<# Bucket E: slack -- Slack Desktop cache (NOT login, NOT message history) #>
param([switch]$DryRun, [switch]$Yes, [int]$Days = 30, [hashtable]$SharedResult)

$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $here "_sweep.ps1")

$result = New-CleanResult -Category "slack" -Label "Slack cache (login + history SAFE)" -Bucket "E"

$appdata = Get-AppDataPath
$local   = Get-LocalAppDataPath
if ([string]::IsNullOrWhiteSpace($appdata)) {
    $result.Notes += "APPDATA not set"
    Set-CleanResultStatus -Result $result -DryRun:$DryRun
    return $result
}

# Slack Desktop is Electron-based. Two install variants:
#   1. Standard MSI/Choco install   -> %APPDATA%\Slack
#   2. Microsoft Store / WindowsApps -> %LOCALAPPDATA%\Packages\91750D7E.Slack_*\LocalCache\Roaming\Slack
$slackRoots = @( (Join-Path $appdata "Slack") )

# Discover any MS Store variant -- glob the package family name.
if (-not [string]::IsNullOrWhiteSpace($local)) {
    $packagesDir = Join-Path $local "Packages"
    if (Test-Path -LiteralPath $packagesDir) {
        try {
            $storeRoots = Get-ChildItem -LiteralPath $packagesDir -Directory -ErrorAction SilentlyContinue |
                          Where-Object { $_.Name -like "*Slack*" }
            foreach ($s in $storeRoots) {
                $candidate = Join-Path $s.FullName "LocalCache\Roaming\Slack"
                if (Test-Path -LiteralPath $candidate) { $slackRoots += $candidate }
            }
        } catch {
            Write-Log "slack store enumerate failed: $($_.Exception.Message)" -Level "warn"
        }
    }
}

# Cache-only subpaths -- EXCLUDES:
#   - storage\          (slack-state.json, app-settings, login tokens)
#   - logs\             (kept for diagnostics)
#   - IndexedDB         (offline message cache -- removing logs you out of unread state)
#   - Local Storage     (auth + workspace tokens)
#   - Session Storage
$cacheSubs = @(
    "Cache",
    "Code Cache",
    "GPUCache",
    "blob_storage",
    "Service Worker\CacheStorage",
    "Service Worker\ScriptCache",
    "Crashpad\completed",
    "logs\preload-logs"
)

$anyFound = $false
foreach ($root in $slackRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $anyFound = $true
    foreach ($sub in $cacheSubs) {
        $p = Join-Path $root $sub
        if (Test-Path -LiteralPath $p) {
            Invoke-PathSweep -Path $p -Result $result -DryRun:$DryRun -LogPrefix "slack/$sub"
        }
    }
}

if (-not $anyFound) {
    $result.Notes += "Slack Desktop not installed"
}

Set-CleanResultStatus -Result $result -DryRun:$DryRun
return $result
