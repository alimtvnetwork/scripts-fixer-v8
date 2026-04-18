<#
.SYNOPSIS
    Helper to launch the Chris Titus Windows Utility.
#>

$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Invoke-WindowsTweaks {
    param(
        [PSCustomObject]$Config,
        $LogMessages
    )

    $url = $Config.url
    Write-Log ($LogMessages.messages.launchUrl -replace '\{url\}', $url) -Level "info"

    # Optional confirmation prompt
    $shouldConfirm = $Config.confirmBeforeRun
    $hasOrchestratorEnv = -not [string]::IsNullOrWhiteSpace($env:SCRIPTS_ROOT_RUN)
    if ($shouldConfirm -and -not $hasOrchestratorEnv) {
        Write-Host ""
        Write-Host "  $($LogMessages.messages.confirm)" -ForegroundColor Yellow
        $answer = Read-Host "  "
        $isNo = $answer -notin @("Y", "y", "Yes", "yes")
        if ($isNo) {
            Write-Log $LogMessages.messages.cancelled -Level "warn"
            return $false
        }
    }

    Write-Log $LogMessages.messages.launching -Level "info"

    try {
        $script = Invoke-RestMethod -Uri $url -UseBasicParsing
        Invoke-Expression $script

        Save-ResolvedData -ScriptFolder "15-windows-tweaks" -Data @{
            tweaks = @{
                url        = $url
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        Write-Log $LogMessages.messages.launchSuccess -Level "success"
        return $true
    } catch {
        Write-Log ($LogMessages.messages.launchFailed -replace '\{error\}', $_) -Level "error"
        return $false
    }
}
function Uninstall-WindowsTweaks {
    <#
    .SYNOPSIS
        Windows Tweaks uninstall: removes tracking records only
        (system tweaks cannot be automatically reverted).
    #>
    param(
        $Config,
        $LogMessages
    )

    Write-Log "Windows Tweaks uninstall: removing tracking records only (tweaks cannot be auto-reverted)" -Level "warn"

    # Remove tracking records
    Remove-InstalledRecord -Name "windows-tweaks"
    Remove-ResolvedData -ScriptFolder "15-windows-tweaks"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
