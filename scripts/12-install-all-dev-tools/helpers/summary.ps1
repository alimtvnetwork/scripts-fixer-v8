# --------------------------------------------------------------------------
#  Orchestrator helper -- Show-Summary
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Show-Summary {
    param(
        $Results,
        $LogMessages
    )

    $list = New-Object System.Collections.ArrayList
    $pending = New-Object System.Collections.ArrayList

    if ($null -ne $Results) {
        [void]$pending.Add($Results)
    }

    while ($pending.Count -gt 0) {
        $currentIndex = $pending.Count - 1
        $current = $pending[$currentIndex]
        $pending.RemoveAt($currentIndex)

        $isHashtable = $current -is [hashtable]
        $isDictionaryEntry = $current -is [System.Collections.DictionaryEntry]
        $hasStatusProperty = $null -ne ($current | Get-Member -Name 'Status' -MemberType NoteProperty, Property -ErrorAction SilentlyContinue)

        if ($isHashtable -or $hasStatusProperty) {
            [void]$list.Add($current)
            continue
        }

        if ($isDictionaryEntry) {
            $entryKey = [string]$current.Key
            $entryValue = $current.Value
            if ($entryKey -in @('Id', 'Name', 'Status')) {
                continue
            }

            if ($null -ne $entryValue) {
                [void]$pending.Add($entryValue)
            }
            continue
        }

        $isEnumerable = ($current -is [System.Collections.IEnumerable]) -and -not ($current -is [string])
        if ($isEnumerable) {
            $items = @($current)
            for ($i = $items.Count - 1; $i -ge 0; $i--) {
                [void]$pending.Add($items[$i])
            }
        }
    }

    Write-Host ""
    Write-Log $LogMessages.messages.summaryHeader -Level "info"

    foreach ($r in $list) {
        $badge = switch ($r.Status) {
            "success"  { "OK" }
            "failed"   { "FAIL" }
            "skipped"  { "SKIP" }
            "disabled" { "OFF" }
            default     { "??" }
        }
        $level = switch ($r.Status) {
            "success"  { "success" }
            "failed"   { "error" }
            default     { "warn" }
        }
        $msg = $LogMessages.messages.summaryItem -replace '\{status\}', $badge -replace '\{id\}', $r.Id -replace '\{name\}', $r.Name
        Write-Log $msg -Level $level
    }

    Write-Host ""
}