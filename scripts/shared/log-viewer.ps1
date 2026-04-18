# --------------------------------------------------------------------------
#  Log Viewer -- Reads scripts/logs/ and displays a summary table
#  Usage: .\scripts\shared\log-viewer.ps1 [-Detail <name>] [-Errors] [-Help]
# --------------------------------------------------------------------------
param(
    [string]$Detail,
    [switch]$Errors,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$logsDir = Join-Path (Split-Path -Parent $PSScriptRoot) "logs"

# -- Help ---------------------------------------------------------------------
if ($Help) {
    Write-Host ""
    Write-Host "  Log Viewer" -ForegroundColor Cyan
    Write-Host "  ----------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    .\scripts\shared\log-viewer.ps1              Show summary table"
    Write-Host "    .\scripts\shared\log-viewer.ps1 -Errors      Show only failed scripts"
    Write-Host "    .\scripts\shared\log-viewer.ps1 -Detail <n>  Show events for a specific log"
    Write-Host "    .\scripts\shared\log-viewer.ps1 -Help        Show this help"
    Write-Host ""
    Write-Host "  Examples:" -ForegroundColor Yellow
    Write-Host "    .\scripts\shared\log-viewer.ps1 -Detail install-golang"
    Write-Host "    .\scripts\shared\log-viewer.ps1 -Errors"
    Write-Host ""
    return
}

# -- Check logs dir exists ----------------------------------------------------
$isLogsDirMissing = -not (Test-Path $logsDir)
if ($isLogsDirMissing) {
    Write-Host ""
    Write-Host "  [ WARN ] No logs directory found at: $logsDir" -ForegroundColor Yellow
    Write-Host "  Run a script first to generate logs." -ForegroundColor DarkGray
    Write-Host ""
    return
}

# -- Load all log files -------------------------------------------------------
$logFiles = Get-ChildItem -Path $logsDir -Filter "*.json" | Where-Object {
    $_.Name -notmatch '-error\.json$'
} | Sort-Object Name

$hasNoLogs = $logFiles.Count -eq 0
if ($hasNoLogs) {
    Write-Host ""
    Write-Host "  [ WARN ] No log files found in: $logsDir" -ForegroundColor Yellow
    Write-Host "  Run a script first to generate logs." -ForegroundColor DarkGray
    Write-Host ""
    return
}

# -- Detail mode: show events for one script ----------------------------------
$isDetailMode = -not [string]::IsNullOrWhiteSpace($Detail)
if ($isDetailMode) {
    $detailFile = Join-Path $logsDir "$Detail.json"
    $isDetailMissing = -not (Test-Path $detailFile)
    if ($isDetailMissing) {
        Write-Host ""
        Write-Host "  [ FAIL ] Log not found: $detailFile" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Available logs:" -ForegroundColor Yellow
        foreach ($f in $logFiles) {
            $name = $f.BaseName
            Write-Host "    $name" -ForegroundColor DarkGray
        }
        Write-Host ""
        return
    }

    $data = Get-Content $detailFile -Raw | ConvertFrom-Json

    Write-Host ""
    Write-Host "  Log Detail: $($data.scriptName)" -ForegroundColor Cyan
    Write-Host "  $('=' * (14 + $data.scriptName.Length))" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Status:     " -NoNewline -ForegroundColor DarkGray
    $statusColor = if ($data.status -eq "ok") { "Green" } else { "Red" }
    Write-Host $data.status -ForegroundColor $statusColor
    Write-Host "  Start:      $($data.startTime)" -ForegroundColor DarkGray
    Write-Host "  End:        $($data.endTime)" -ForegroundColor DarkGray
    Write-Host "  Duration:   $($data.duration)s" -ForegroundColor DarkGray
    Write-Host "  Events:     $($data.eventCount)" -ForegroundColor DarkGray
    Write-Host "  Errors:     $($data.errorCount)" -ForegroundColor DarkGray
    Write-Host ""

    $badgeMap = @{ ok = "[  OK  ]"; fail = "[ FAIL ]"; info = "[ INFO ]"; warn = "[ WARN ]"; skip = "[ SKIP ]" }
    $colorMap = @{ ok = "Green"; fail = "Red"; info = "Cyan"; warn = "Yellow"; skip = "DarkGray" }

    foreach ($evt in $data.events) {
        $lvl   = $evt.level
        $badge = $badgeMap[$lvl]
        $color = $colorMap[$lvl]
        $isBadgeMissing = -not $badge
        if ($isBadgeMissing) { $badge = "[ ???? ]"; $color = "White" }

        $ts = ""
        try {
            $parsed = [DateTime]::Parse($evt.timestamp)
            $ts = $parsed.ToString("HH:mm:ss.fff")
        } catch { $ts = "--------" }

        Write-Host "  $ts " -NoNewline -ForegroundColor DarkGray
        Write-Host "$badge " -NoNewline -ForegroundColor $color
        Write-Host $evt.message
    }

    # Show error file if exists
    $errorFile = Join-Path $logsDir "$Detail-error.json"
    $hasErrorFile = Test-Path $errorFile
    if ($hasErrorFile) {
        Write-Host ""
        Write-Host "  Error log available: $Detail-error.json" -ForegroundColor Yellow
    }

    Write-Host ""
    return
}

# -- Summary table mode -------------------------------------------------------
$logs = @()
foreach ($file in $logFiles) {
    try {
        $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $logs += @{
            Name       = $data.scriptName
            Status     = $data.status
            Duration   = $data.duration
            Events     = $data.eventCount
            Errors     = $data.errorCount
            StartTime  = $data.startTime
        }
    } catch {
        $logs += @{
            Name       = $file.BaseName
            Status     = "parse-error"
            Duration   = 0
            Events     = 0
            Errors     = 0
            StartTime  = ""
        }
    }
}

# Filter errors only
if ($Errors) {
    $logs = $logs | Where-Object { $_.Status -ne "ok" }
    $hasNoErrors = $logs.Count -eq 0
    if ($hasNoErrors) {
        Write-Host ""
        Write-Host "  [  OK  ] All scripts completed successfully -- no errors found." -ForegroundColor Green
        Write-Host ""
        return
    }
}

# Calculate column widths
$nameWidth = ($logs | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
$nameWidth = [Math]::Max($nameWidth, 6)

Write-Host ""
Write-Host "  Script Log Summary" -ForegroundColor Cyan
Write-Host "  ==================" -ForegroundColor DarkGray
Write-Host ""

# Header
$header = "  {0}  {1}  {2}  {3}  {4}" -f `
    "Name".PadRight($nameWidth),
    "Status".PadRight(8),
    "Duration".PadRight(10),
    "Events".PadRight(7),
    "Errors"
Write-Host $header -ForegroundColor Yellow
Write-Host "  $('-' * ($nameWidth + 40))" -ForegroundColor DarkGray

# Rows
$okCount   = 0
$failCount = 0

foreach ($log in $logs) {
    $name     = $log.Name.PadRight($nameWidth)
    $status   = $log.Status.PadRight(8)
    $duration = "$($log.Duration)s".PadRight(10)
    $events   = "$($log.Events)".PadRight(7)
    $errors   = "$($log.Errors)"

    $statusColor = switch ($log.Status) {
        "ok"    { "Green" }
        "fail"  { "Red" }
        default { "Yellow" }
    }

    $isOk = $log.Status -eq "ok"
    if ($isOk) { $okCount++ } else { $failCount++ }

    Write-Host "  " -NoNewline
    Write-Host $name -NoNewline
    Write-Host "  " -NoNewline
    Write-Host $status -NoNewline -ForegroundColor $statusColor
    Write-Host "  " -NoNewline
    Write-Host $duration -NoNewline -ForegroundColor DarkGray
    Write-Host "  " -NoNewline
    Write-Host $events -NoNewline -ForegroundColor DarkGray
    Write-Host "  " -NoNewline

    $hasErrors = $log.Errors -gt 0
    if ($hasErrors) {
        Write-Host $errors -ForegroundColor Red
    } else {
        Write-Host $errors -ForegroundColor DarkGray
    }
}

# Footer
Write-Host "  $('-' * ($nameWidth + 40))" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Total: $($logs.Count) scripts  " -NoNewline -ForegroundColor DarkGray
Write-Host "$okCount ok" -NoNewline -ForegroundColor Green
Write-Host "  " -NoNewline
$hasFailures = $failCount -gt 0
if ($hasFailures) {
    Write-Host "$failCount failed" -ForegroundColor Red
} else {
    Write-Host "$failCount failed" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  Tip: Use -Detail <name> to see events for a specific script" -ForegroundColor DarkGray
Write-Host "       Use -Errors to show only failed scripts" -ForegroundColor DarkGray
Write-Host ""
