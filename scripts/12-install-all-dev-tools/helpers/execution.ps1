# --------------------------------------------------------------------------
#  Orchestrator helper -- Invoke-ScriptSequence & Invoke-UninstallSequence
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Invoke-ScriptSequence {
    param(
        $ScriptList,
        [string]$ScriptsRoot,
        $LogMessages,
        [string]$Skip
    )

    # Normalize: ensure $ScriptList is always a proper list
    $ScriptList = if ($ScriptList -is [hashtable]) { ,@($ScriptList) } else { @($ScriptList) }

    $skipList = if ($Skip) { $Skip -split ',' | ForEach-Object { $_.Trim() } } else { @() }
    $results  = New-Object System.Collections.ArrayList

    # Signal child scripts that the orchestrator is driving execution
    $env:SCRIPTS_ROOT_RUN = "1"

    foreach ($script in $ScriptList) {
        $id   = $script.Id
        $name = $script.Name

        # Skip disabled
        $isDisabled = -not $script.Enabled
        if ($isDisabled) {
            Write-Log ($LogMessages.messages.scriptDisabled -replace '\{id\}', $id -replace '\{name\}', $name) -Level "warn"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "disabled" })
            continue
        }

        # Skip user-requested
        $isSkipped = $id -in $skipList
        if ($isSkipped) {
            Write-Log ($LogMessages.messages.scriptSkipped -replace '\{id\}', $id -replace '\{name\}', $name) -Level "warn"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "skipped" })
            continue
        }

        Write-Log ($LogMessages.messages.runningScript -replace '\{id\}', $id -replace '\{name\}', $name) -Level "info"

        $scriptPath = Join-Path $ScriptsRoot "$($script.Folder)\run.ps1"

        try {
            & $scriptPath
            Write-Log ($LogMessages.messages.scriptSuccess -replace '\{id\}', $id) -Level "success"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "success" })
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Log ($LogMessages.messages.scriptFailed -replace '\{id\}', $id -replace '\{error\}', $errMsg) -Level "error"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "failed" })
        }
    }

    # Clean up so the flag doesn't leak into the caller's session
    Remove-Item Env:\SCRIPTS_ROOT_RUN -ErrorAction SilentlyContinue

    return ,@($results)
}

function Invoke-UninstallSequence {
    <#
    .SYNOPSIS
        Runs the uninstall subcommand for each script in the list.
        Scripts are processed in reverse order (last installed = first uninstalled).
        Script 02 (Chocolatey) is always skipped to avoid breaking the uninstall chain.
    #>
    param(
        $ScriptList,
        [string]$ScriptsRoot,
        $LogMessages
    )

    # Normalize
    $ScriptList = if ($ScriptList -is [hashtable]) { ,@($ScriptList) } else { @($ScriptList) }

    # Reverse order: uninstall last-installed first
    $reversed = [System.Collections.ArrayList]::new()
    for ($i = $ScriptList.Count - 1; $i -ge 0; $i--) {
        [void]$reversed.Add($ScriptList[$i])
    }

    $results = New-Object System.Collections.ArrayList

    foreach ($script in $reversed) {
        $id   = $script.Id
        $name = $script.Name

        # Never uninstall Chocolatey (02) -- it would break everything
        $isChocolatey = $id -eq "02"
        if ($isChocolatey) {
            Write-Log ($LogMessages.messages.uninstallSkipChoco -replace '\{id\}', $id -replace '\{name\}', $name) -Level "warn"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "skipped" })
            continue
        }

        Write-Log ($LogMessages.messages.uninstallRunning -replace '\{id\}', $id -replace '\{name\}', $name) -Level "info"

        $scriptPath = Join-Path $ScriptsRoot "$($script.Folder)\run.ps1"

        try {
            & $scriptPath uninstall
            Write-Log ($LogMessages.messages.uninstallScriptSuccess -replace '\{id\}', $id) -Level "success"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "success" })
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Log ($LogMessages.messages.uninstallScriptFailed -replace '\{id\}', $id -replace '\{error\}', $errMsg) -Level "error"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "failed" })
        }
    }

    return ,@($results)
}
