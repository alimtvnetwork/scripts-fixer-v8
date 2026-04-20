<#
  Bucket E: onedrive-cache -- OneDrive client cache (NOT synced files)

  CRITICAL SAFETY: This helper NEVER touches the user's synced OneDrive folder
  ($env:OneDrive / %USERPROFILE%\OneDrive*). It only sweeps the client-side
  metadata + setup + log + thumbnail caches under %LOCALAPPDATA%\Microsoft\OneDrive.
  Synced files, online-only placeholders, and the offline cache of pinned files
  are explicitly excluded.
#>
param([switch]$DryRun, [switch]$Yes, [int]$Days = 30, [hashtable]$SharedResult)

$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $here "_sweep.ps1")

$result = New-CleanResult -Category "onedrive-cache" -Label "OneDrive client cache (synced files SAFE)" -Bucket "E"

$local = Get-LocalAppDataPath
if ([string]::IsNullOrWhiteSpace($local)) {
    $result.Notes += "LOCALAPPDATA not set"
    Set-CleanResultStatus -Result $result -DryRun:$DryRun
    return $result
}

$root = Join-Path $local "Microsoft\OneDrive"
if (-not (Test-Path -LiteralPath $root)) {
    $result.Notes += "OneDrive client not installed"
    Set-CleanResultStatus -Result $result -DryRun:$DryRun
    return $result
}

# Cache-only subpaths -- EXPLICITLY EXCLUDES:
#   - settings\         (account binding + sync state -- removing it forces re-link)
#   - %OneDrive%\       (the actual synced folder -- NEVER touched, lives outside this root)
#   - StorageProvider\  (Files-On-Demand placeholders -- removing breaks online-only files)
$cacheSubs = @(
    "logs",
    "setup\logs",
    "ListSync\Cache",
    "ListSync\Logs",
    "Update",
    "EnterpriseUpdate",
    "BackupTool\logs"
)

# Thumbnails are stored as thumb*.dat directly under the root -- sweep matching
# files only, never the whole root.
$anyFound = $false
foreach ($sub in $cacheSubs) {
    $p = Join-Path $root $sub
    if (Test-Path -LiteralPath $p) {
        $anyFound = $true
        Invoke-PathSweep -Path $p -Result $result -DryRun:$DryRun -LogPrefix "onedrive/$sub"
    }
}

# Loose cache files at root level (thumbnails, telemetry queue)
$looseFilePatterns = @("thumb*.dat", "TelemetryCache*.otc", "*.tmp")
foreach ($pattern in $looseFilePatterns) {
    try {
        $files = Get-ChildItem -LiteralPath $root -File -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $anyFound = $true
            if ($DryRun) {
                $result.WouldFreeBytes += [int64]$f.Length
                $result.WouldDeleteCount += 1
                Write-Log "[DRY-RUN] onedrive/root would delete $($f.FullName) ($($f.Length) bytes)" -Level "info"
            } else {
                try {
                    Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                    $result.FreedBytes += [int64]$f.Length
                    $result.DeletedCount += 1
                } catch {
                    $result.LockedFiles += $f.FullName
                    Write-Log "onedrive/root LOCKED: $($f.FullName) reason: $($_.Exception.Message)" -Level "warn"
                }
            }
        }
    } catch {
        Write-Log "onedrive root enumerate failed for ${pattern}: $($_.Exception.Message)" -Level "warn"
    }
}

if (-not $anyFound) {
    $result.Notes += "OneDrive client cache directories not found (no caches to clean)"
}

Set-CleanResultStatus -Result $result -DryRun:$DryRun
return $result
