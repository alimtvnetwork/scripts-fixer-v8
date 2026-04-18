# --------------------------------------------------------------------------
#  Orchestrator helper -- Resolve-ScriptList
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Resolve-ScriptList {
    param(
        $Config,
        [string]$Skip,
        [string]$Only
    )

    $sequence = $Config.sequence
    $scripts  = $Config.scripts

    # --only filter
    if ($Only) {
        $onlyList = $Only -split ',' | ForEach-Object { $_.Trim() }
        $sequence = $sequence | Where-Object { $_ -in $onlyList }
    }

    # --skip filter
    if ($Skip) {
        $skipList = $Skip -split ',' | ForEach-Object { $_.Trim() }
        $sequence = $sequence | Where-Object { $_ -notin $skipList }
    }

    # Build result list using ArrayList to prevent single-item unwrapping
    $result = New-Object System.Collections.ArrayList
    foreach ($id in $sequence) {
        $entry = $scripts.$id
        $hasNoEntry = -not $entry
        if ($hasNoEntry) { continue }

        [void]$result.Add(@{
            Id              = $id
            Folder          = $entry.folder
            Name            = $entry.name
            Desc            = if ($entry.desc) { $entry.desc } else { "" }
            Enabled         = $entry.enabled
        })
    }

    return ,@($result)
}