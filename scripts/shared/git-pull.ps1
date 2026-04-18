<#
.SYNOPSIS
    Shared git-pull helper. Dot-source this from any script to get Invoke-GitPull.

.DESCRIPTION
    Provides Invoke-GitPull which runs 'git pull' from the repository root.
    Skips automatically if $env:SCRIPTS_ROOT_RUN is set (meaning the root
    dispatcher already performed the pull).

    Can be called with -RepoRoot or without (auto-detects from caller location).

.NOTES
    Author : Lovable AI
    Version: 1.3.0
#>

# -- Bootstrap shared helpers --------------------------------------------------
$loggingPath = Join-Path $PSScriptRoot "logging.ps1"
$isLoggingAvailable = Test-Path $loggingPath
if ($isLoggingAvailable -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $loggingPath
}

if (-not (Get-Variable -Name SharedLogMessages -Scope Script -ErrorAction SilentlyContinue)) {
    $sharedLogPath = Join-Path $PSScriptRoot "log-messages.json"
    $isSharedLogFound = Test-Path $sharedLogPath
    if ($isSharedLogFound) {
        $script:SharedLogMessages = Get-Content $sharedLogPath -Raw | ConvertFrom-Json
    }
}

function Format-GitPullOutput {
    param(
        [string]$RawOutput
    )

    $lines = $RawOutput -split "`n" | ForEach-Object { $_.TrimEnd() }

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # Skip empty lines
        $isEmpty = $trimmed.Length -eq 0
        if ($isEmpty) { continue }

        # "Already up to date" or similar status
        $isUpToDate = $trimmed -match "^Already up to date"
        if ($isUpToDate) {
            Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
            Write-Host $trimmed
            continue
        }

        # "From https://..." line
        $isFromLine = $trimmed -match "^From "
        if ($isFromLine) {
            Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
            Write-Host $trimmed
            continue
        }

        # Branch tracking line (e.g., "a3eb793..b3447d0  main -> origin/main")
        $isBranchLine = $trimmed -match "\.\." -and $trimmed -match "->"
        if ($isBranchLine) {
            Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
            Write-Host $trimmed
            continue
        }

        # "Updating ..." line
        $isUpdatingLine = $trimmed -match "^Updating "
        if ($isUpdatingLine) {
            Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline
            Write-Host $trimmed
            continue
        }

        # "Fast-forward" line
        $isFastForward = $trimmed -match "^Fast-forward"
        if ($isFastForward) {
            Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
            Write-Host "Fast-forward merge"
            continue
        }

        # File change lines (e.g., " scripts/foo/run.ps1 | 42 +++++---")
        $isFileChange = $trimmed -match "^(.+?)\s+\|\s+(\d+)\s*([+\-]*)\s*$"
        if ($isFileChange) {
            $fileName    = $Matches[1].Trim()
            $changeCount = $Matches[2]
            $plusMinus   = $Matches[3]

            # Color the +/- characters
            Write-Host "  [  --  ] " -ForegroundColor DarkGray -NoNewline
            Write-Host "$fileName " -NoNewline -ForegroundColor White
            Write-Host "| " -NoNewline -ForegroundColor DarkGray
            Write-Host "$changeCount " -NoNewline -ForegroundColor Yellow

            # Print each + in green and each - in red
            foreach ($char in $plusMinus.ToCharArray()) {
                $isPlus = $char -eq '+'
                if ($isPlus) {
                    Write-Host $char -NoNewline -ForegroundColor Green
                } else {
                    Write-Host $char -NoNewline -ForegroundColor Red
                }
            }
            Write-Host ""
            continue
        }

        # Binary file lines
        $isBinaryLine = $trimmed -match "^(.+?)\s+\|\s+Bin"
        if ($isBinaryLine) {
            Write-Host "  [  --  ] " -ForegroundColor DarkGray -NoNewline
            Write-Host $trimmed
            continue
        }

        # Summary line (e.g., "33 files changed, 1351 insertions(+), 311 deletions(-)")
        $isSummaryLine = $trimmed -match "files? changed"
        if ($isSummaryLine) {
            Write-Host ""
            Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
            Write-Host $trimmed -ForegroundColor White
            continue
        }

        # Create/delete/rename mode lines
        $isModeLine = $trimmed -match "^(create|delete|rename|copy) mode"
        if ($isModeLine) {
            $modeColor = if ($trimmed -match "^create") { "Green" }
                         elseif ($trimmed -match "^delete") { "Red" }
                         else { "Yellow" }
            Write-Host "  [  --  ] " -ForegroundColor DarkGray -NoNewline
            Write-Host $trimmed -ForegroundColor $modeColor
            continue
        }

        # Fallback: print as-is
        Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline
        Write-Host $trimmed
    }
}

function Invoke-GitPull {
    param(
        [string]$RepoRoot
    )

    $slm = $script:SharedLogMessages

    # Auto-detect repo root if not provided
    $isRepoRootMissing = -not $RepoRoot
    if ($isRepoRootMissing) {
        $callerDir = if ($script:ScriptDir) { $script:ScriptDir }
                     elseif ($scriptDir) { $scriptDir }
                     else { Split-Path -Parent $MyInvocation.PSCommandPath }
        $RepoRoot = Split-Path -Parent (Split-Path -Parent $callerDir)
    }

    # Skip if the root dispatcher already ran git pull
    if ($env:SCRIPTS_ROOT_RUN -eq "1") {
        Write-Log $slm.messages.gitPullSkipped -Level "skip"
        return
    }

    Write-Log $slm.messages.gitPulling -Level "info"

    try {
        Push-Location $RepoRoot
        # Capture each line as a string (stderr ErrorRecords need .ToString())
        $gitLines  = git pull 2>&1 | ForEach-Object { $_.ToString() }
        $gitOutput = $gitLines -join "`n"
        Pop-Location

        Format-GitPullOutput -RawOutput $gitOutput
    } catch {
        Pop-Location
        Write-Log ($slm.messages.gitPullFailed -replace '\{error\}', $_) -Level "warn"
    }
}
