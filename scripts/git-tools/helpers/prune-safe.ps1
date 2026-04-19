<#
.SYNOPSIS
    Removes orphaned safe.directory entries -- repos that no longer exist on disk.

.DESCRIPTION
    Workflow:
      1. Snapshot every `git config --global --get-all safe.directory` -> $before
      2. For each per-repo entry (skip wildcard '*' -- never pruned):
           - Normalize to local filesystem path
           - Test-Path; if missing, mark as orphan
      3. For each orphan, run git config --global --unset-all safe.directory
         with the exact-match regex pattern
      4. Snapshot AFTER -> verify count delta == orphan count
      5. Print before / orphans / after with full per-orphan list

    Wildcard '*' is NEVER pruned (it doesn't represent a path).
    -DryRun reports what WOULD be removed without changing anything.

    CODE RED: every error logs the exact path + reason.
#>
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$gitToolsDir = Split-Path -Parent $scriptDir
$sharedDir   = Join-Path (Split-Path -Parent $gitToolsDir) "shared"

. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "json-utils.ps1")

$logMessages = Import-JsonConfig (Join-Path $gitToolsDir "log-messages.json")
Initialize-Logging -ScriptName "git-safe-prune"

# -- Pre-flight: git must be available --------------------------------
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
$isGitMissing = $null -eq $gitCmd
if ($isGitMissing) {
    Write-Host "  $($logMessages.status.fail) " -ForegroundColor Red -NoNewline
    Write-Host $logMessages.messages.gitMissing
    Save-LogFile -Status "fail"
    exit 1
}

Write-Host ""
$header = if ($DryRun) { $logMessages.messages.pruneHeaderDry } else { $logMessages.messages.pruneHeader }
Write-Host "  $header" -ForegroundColor Cyan
Write-Host "  =========================================" -ForegroundColor DarkGray
Write-Host ""

# -- Snapshot BEFORE --------------------------------------------------
function Get-SafeEntries {
    $raw = & git config --global --get-all safe.directory 2>$null
    $hasOutput = $null -ne $raw
    if (-not $hasOutput) { return @() }
    return @($raw)
}

$before      = Get-SafeEntries
$beforeCount = $before.Count

$isEmpty = $beforeCount -eq 0
if ($isEmpty) {
    Write-Host "  $($logMessages.status.warn) " -ForegroundColor Yellow -NoNewline
    Write-Host $logMessages.messages.pruneEmpty
    Write-Host ""
    Save-LogFile -Status "ok"
    exit 0
}

# -- Classify entries -------------------------------------------------
$wildcards = @($before | Where-Object { $_ -eq '*' })
$repoEntries = @($before | Where-Object { $_ -ne '*' } | Sort-Object -Unique)

$wildcardCount = $wildcards.Count
$repoCount     = $repoEntries.Count

$wildcardMsg = $logMessages.messages.pruneClassify `
    -replace '\{total\}',    "$beforeCount" `
    -replace '\{wildcard\}', "$wildcardCount" `
    -replace '\{repos\}',    "$repoCount"
Write-Host "  $($logMessages.status.info) " -ForegroundColor DarkGray -NoNewline
Write-Host $wildcardMsg
Write-Host ""

# -- Find orphans -----------------------------------------------------
$orphans = @()
$alive   = @()

foreach ($entry in $repoEntries) {
    # git stores paths with forward slashes; Test-Path accepts either on Windows
    $pathToTest = $entry
    $isAlive = Test-Path -LiteralPath $pathToTest -ErrorAction SilentlyContinue
    if ($isAlive) {
        $alive += $entry
    } else {
        $orphans += $entry
    }
}

$orphanCount = $orphans.Count
$aliveCount  = $alive.Count

$hasOrphans = $orphanCount -gt 0
if (-not $hasOrphans) {
    Write-Host "  $($logMessages.status.ok) " -ForegroundColor Green -NoNewline
    Write-Host $logMessages.messages.pruneNoOrphans
    Write-Host ""

    $summaryMsg = $logMessages.messages.pruneSummary `
        -replace '\{before\}',  "$beforeCount" `
        -replace '\{after\}',   "$beforeCount" `
        -replace '\{orphans\}', "0" `
        -replace '\{alive\}',   "$aliveCount"
    Write-Host "  $($logMessages.status.info) " -ForegroundColor DarkGray -NoNewline
    Write-Host $summaryMsg
    Write-Host ""

    Save-LogFile -Status "ok"
    exit 0
}

# -- List orphans (always shown, dry-run or not) ----------------------
$listLabel = if ($DryRun) { $logMessages.messages.pruneOrphansListDry } else { $logMessages.messages.pruneOrphansList }
$listMsg = $listLabel -replace '\{count\}', "$orphanCount"
Write-Host "  $listMsg" -ForegroundColor Yellow
Write-Host "  -------------------------------" -ForegroundColor DarkGray
$idx = 1
foreach ($o in $orphans) {
    $num = "{0,4}." -f $idx
    Write-Host "  $num " -ForegroundColor DarkGray -NoNewline
    Write-Host $o -ForegroundColor DarkYellow
    $idx++
}
Write-Host ""

# -- Dry-run early exit -----------------------------------------------
if ($DryRun) {
    Write-Host "  $($logMessages.status.info) " -ForegroundColor DarkGray -NoNewline
    Write-Host $logMessages.messages.pruneDryRunNote
    Write-Host ""

    $summaryMsg = $logMessages.messages.pruneSummary `
        -replace '\{before\}',  "$beforeCount" `
        -replace '\{after\}',   "$beforeCount" `
        -replace '\{orphans\}', "$orphanCount" `
        -replace '\{alive\}',   "$aliveCount"
    Write-Host "  $($logMessages.status.info) " -ForegroundColor DarkGray -NoNewline
    Write-Host $summaryMsg
    Write-Host ""

    Save-LogFile -Status "ok"
    exit 0
}

# -- Live run: unset each orphan --------------------------------------
$removed = 0
$failed  = @()

foreach ($orphan in $orphans) {
    $escaped      = [regex]::Escape($orphan)
    $valuePattern = "^$escaped$"

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
        $failMsg = $logMessages.messages.pruneEntryFailed `
            -replace '\{path\}',   $orphan `
            -replace '\{reason\}', $unsetReason
        Write-Host "  $($logMessages.status.fail) " -ForegroundColor Red -NoNewline
        Write-Host $failMsg
        $failed += @{ Path = $orphan; Reason = $unsetReason }
    } else {
        $removed++
    }
}

# -- Snapshot AFTER + verify ------------------------------------------
$after       = Get-SafeEntries
$afterCount  = $after.Count

$expectedAfter = $beforeCount - $removed
$isCountMatch  = $afterCount -eq $expectedAfter
if (-not $isCountMatch) {
    $driftMsg = $logMessages.messages.pruneCountDrift `
        -replace '\{expected\}', "$expectedAfter" `
        -replace '\{actual\}',   "$afterCount"
    Write-Host "  $($logMessages.status.warn) " -ForegroundColor Yellow -NoNewline
    Write-Host $driftMsg
}

Write-Host ""
$summaryMsg = $logMessages.messages.pruneSummary `
    -replace '\{before\}',  "$beforeCount" `
    -replace '\{after\}',   "$afterCount" `
    -replace '\{orphans\}', "$orphanCount" `
    -replace '\{alive\}',   "$aliveCount"

$summaryStatus = if ($failed.Count -gt 0) { $logMessages.status.warn } else { $logMessages.status.ok }
$summaryColor  = if ($failed.Count -gt 0) { "Yellow" } else { "Green" }
Write-Host "  $summaryStatus " -ForegroundColor $summaryColor -NoNewline
Write-Host $summaryMsg
Write-Host ""

$finalStatus = if ($failed.Count -gt 0) { "partial" } else { "ok" }
Save-LogFile -Status $finalStatus
exit 0
