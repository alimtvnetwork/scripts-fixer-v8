<#
.SYNOPSIS
    Removes a single safe.directory entry from global gitconfig.

.DESCRIPTION
    Idempotent. Workflow:
      1. Snapshot current `git config --global --get-all safe.directory` -> $before
      2. Check if -Path is present at all -> if not, [ SKIP ] with clear reason
      3. Run `git config --global --unset-all safe.directory <pattern>` where
         pattern is the regex-escaped exact path
      4. Snapshot again -> $after
      5. Print before/after counts + which exact entries got removed

    Path normalization: forward-slashes preserved as-is (git stores them that way).
    The wildcard '*' is removable too -- pass --Path '*' to revoke it.

    CODE RED: every error logs the exact path + reason.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$gitToolsDir = Split-Path -Parent $scriptDir
$sharedDir   = Join-Path (Split-Path -Parent $gitToolsDir) "shared"

. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "json-utils.ps1")

$logMessages = Import-JsonConfig (Join-Path $gitToolsDir "log-messages.json")
Initialize-Logging -ScriptName "git-safe-remove"

# -- Pre-flight: git must be available --------------------------------
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
$isGitMissing = $null -eq $gitCmd
if ($isGitMissing) {
    Write-Host "  $($logMessages.status.fail) " -ForegroundColor Red -NoNewline
    Write-Host $logMessages.messages.gitMissing
    Save-LogFile -Status "fail"
    exit 1
}

# -- Validate -Path argument ------------------------------------------
$isPathBlank = [string]::IsNullOrWhiteSpace($Path)
if ($isPathBlank) {
    Write-Host "  $($logMessages.status.fail) " -ForegroundColor Red -NoNewline
    Write-Host $logMessages.messages.removeMissingPath
    Save-LogFile -Status "fail"
    exit 1
}

$targetPath = $Path.Trim()

Write-Host ""
Write-Host "  $($logMessages.messages.removeHeader)" -ForegroundColor Cyan
Write-Host "  =========================================" -ForegroundColor DarkGray
Write-Host ""

$targetMsg = $logMessages.messages.removeTarget -replace '\{path\}', $targetPath
Write-Host "  $($logMessages.status.info) " -ForegroundColor DarkGray -NoNewline
Write-Host $targetMsg

# -- Snapshot BEFORE --------------------------------------------------
function Get-SafeEntries {
    $raw = & git config --global --get-all safe.directory 2>$null
    $hasOutput = $null -ne $raw
    if (-not $hasOutput) { return @() }
    return @($raw)
}

$before      = Get-SafeEntries
$beforeCount = $before.Count

$matches = @($before | Where-Object { $_ -eq $targetPath })
$matchCount = $matches.Count

$hasMatch = $matchCount -gt 0
if (-not $hasMatch) {
    $skipMsg = $logMessages.messages.removeNotPresent -replace '\{path\}', $targetPath
    Write-Host "  $($logMessages.status.skip) " -ForegroundColor Yellow -NoNewline
    Write-Host $skipMsg
    Write-Host ""

    $summaryMsg = $logMessages.messages.removeSummary `
        -replace '\{before\}',  "$beforeCount" `
        -replace '\{after\}',   "$beforeCount" `
        -replace '\{removed\}', "0"
    Write-Host "  $($logMessages.status.info) " -ForegroundColor DarkGray -NoNewline
    Write-Host $summaryMsg
    Write-Host ""

    Save-LogFile -Status "skip"
    exit 0
}

# -- Build value-pattern for git config --unset-all -------------------
# git config --unset-all uses a regex match against the VALUE.
# Anchor with ^...$ + escape regex metacharacters so we only nuke exact matches.
$escaped     = [regex]::Escape($targetPath)
$valuePattern = "^$escaped$"

# -- Run the unset ----------------------------------------------------
$unsetFailed = $false
$unsetReason = ""
try {
    & git config --global --unset-all safe.directory $valuePattern 2>&1 | Out-Null
    $isGitOk = $LASTEXITCODE -eq 0
    if (-not $isGitOk) {
        $unsetFailed = $true
        $unsetReason = "git exited with code $LASTEXITCODE"
    }
} catch {
    $unsetFailed = $true
    $unsetReason = $_.Exception.Message
}

if ($unsetFailed) {
    $failMsg = $logMessages.messages.removeFailed `
        -replace '\{path\}',   $targetPath `
        -replace '\{reason\}', $unsetReason
    Write-Host "  $($logMessages.status.fail) " -ForegroundColor Red -NoNewline
    Write-Host $failMsg
    Write-Host ""
    Save-LogFile -Status "fail"
    exit 1
}

# -- Snapshot AFTER + verify ------------------------------------------
$after       = Get-SafeEntries
$afterCount  = $after.Count
$removedCount = $beforeCount - $afterCount

$okMsg = $logMessages.messages.removeRemoved `
    -replace '\{path\}',  $targetPath `
    -replace '\{count\}', "$matchCount"
Write-Host "  $($logMessages.status.ok) " -ForegroundColor Green -NoNewline
Write-Host $okMsg
Write-Host ""

$summaryMsg = $logMessages.messages.removeSummary `
    -replace '\{before\}',  "$beforeCount" `
    -replace '\{after\}',   "$afterCount" `
    -replace '\{removed\}', "$removedCount"
Write-Host "  $($logMessages.status.ok) " -ForegroundColor Green -NoNewline
Write-Host $summaryMsg
Write-Host ""

Save-LogFile -Status "ok"
exit 0
