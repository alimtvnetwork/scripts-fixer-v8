<#
.SYNOPSIS
    Chocolatey install/update helpers for script 03.
#>

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-Chocolatey {
    param(
        [PSCustomObject]$Config,
        $LogMessages
    )

    $isDisabled = -not $Config.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.chocoDisabled -Level "info"
        return $true
    }

    $isChocoReady = Assert-Choco
    $isChocoNotReady = -not $isChocoReady
    if ($isChocoNotReady) { return $false }

    $version = & choco.exe --version 2>&1
    $versionStr = "$version".Trim()

    # Check .installed/ tracking -- skip upgrade if version matches
    $isAlreadyTracked = Test-AlreadyInstalled -Name "chocolatey" -CurrentVersion $versionStr
    if ($isAlreadyTracked) {
        Write-Log "Chocolatey $versionStr already tracked -- skipping upgrade" -Level "info"
    }
    elseif ($Config.upgradeOnRun) {
        Write-Log $LogMessages.messages.chocoUpgrading -Level "info"
        try {
            $output = & choco.exe upgrade chocolatey -y 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log ($LogMessages.messages.chocoUpgradeIssues -replace '\{output\}', $output) -Level "warn"
            } else {
                Write-Log $LogMessages.messages.chocoUpToDate -Level "success"
            }
        } catch {
            Write-Log ($LogMessages.messages.chocoUpgradeFailed -replace '\{error\}', $_) -Level "warn"
            Save-InstalledError -Name "chocolatey" -ErrorMessage "$_" -Method "self"
        }

        $version = & choco.exe --version 2>&1
        $versionStr = "$version".Trim()
    }

    Save-InstalledRecord -Name "chocolatey" -Version $versionStr -Method "self"

    # Save resolved info
    Save-ResolvedData -ScriptFolder "02-install-package-managers" -Data @{
        chocolatey = @{
            version    = $versionStr
            resolvedAt = (Get-Date -Format "o")
            resolvedBy = $env:USERNAME
        }
    }

    return $true
}
