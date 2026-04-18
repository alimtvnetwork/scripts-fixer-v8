# --------------------------------------------------------------------------
#  Script 12 -- Install All Dev Tools
#  Orchestrator: front-loads all questions, then runs scripts unattended.
#  Supports: quick menu (All Dev / All Dev+DB / Custom), -All, -Skip, -Only.
#  Also supports -Uninstall to batch-uninstall selected tools.
# --------------------------------------------------------------------------
param(
    [string]$Path,
    [string]$Skip,
    [string]$Only,
    [switch]$All,
    [switch]$DryRun,
    [Alias("D")][switch]$Defaults,
    [switch]$Uninstall,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir   = Join-Path (Split-Path -Parent $scriptDir) "shared"
$scriptsRoot = Split-Path -Parent $scriptDir

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "dev-dir.ps1")
. (Join-Path $sharedDir "installed.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\orchestrator.ps1")

# -- Load config & log messages -----------------------------------------------
$config      = Import-JsonConfig (Join-Path $scriptDir "config.json")
$logMessages = Import-JsonConfig (Join-Path $scriptDir "log-messages.json")

# -- Help ---------------------------------------------------------------------
if ($Help) {
    Show-ScriptHelp -LogMessages $logMessages
    return
}

# -- Banner --------------------------------------------------------------------
Write-Banner -Title $logMessages.scriptName

# -- Initialize logging --------------------------------------------------------
Initialize-Logging -ScriptName $logMessages.scriptName

try {

# -- Git pull ------------------------------------------------------------------
Invoke-GitPull

# -- Assert admin --------------------------------------------------------------
$hasAdminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isNotAdmin = -not $hasAdminRights
if ($isNotAdmin) {
    Write-Log $logMessages.messages.notAdmin -Level "error"
    return
}

# ==============================================================================
#  UNINSTALL MODE
# ==============================================================================
if ($Uninstall) {
    $hasFilter = $Skip -or $Only

    # Build script list
    $scriptList = if ($Only -or $Skip) {
        Resolve-ScriptList -Config $config -Skip $Skip -Only $Only
    } elseif ($All) {
        Resolve-ScriptList -Config $config -Skip "" -Only ""
    } else {
        # Interactive: show menu to pick what to uninstall
        $fullList = Resolve-ScriptList -Config $config -Skip "" -Only ""
        $groups   = if ($config.groups) { $config.groups } else { $null }

        Write-Host ""
        Write-Log $logMessages.messages.uninstallMenuTitle -Level "warn"
        $selected = Show-InteractiveMenu -ScriptList $fullList -LogMessages $logMessages -Groups $groups

        $isUserQuit = $null -eq $selected
        if ($isUserQuit) {
            Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
            return
        }

        $hasNoSelection = $selected.Count -eq 0
        if ($hasNoSelection) {
            Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
            return
        }

        $selected
    }

    # Dry run for uninstall
    if ($DryRun) {
        Write-Host ""
        Write-Log $logMessages.messages.uninstallDryRunBanner -Level "warn"
        Write-Host ""
        foreach ($s in $scriptList) {
            Write-Log ("  [WOULD UNINSTALL] {0} - {1}" -f $s.Id, $s.Name) -Level "info"
        }
        Write-Log ("Dry run complete. {0} script(s) would be uninstalled." -f $scriptList.Count) -Level "success"
        return
    }

    # Confirmation prompt
    Write-Host ""
    Write-Log ($logMessages.messages.uninstallConfirmPrompt -replace '\{count\}', $scriptList.Count) -Level "warn"
    foreach ($s in $scriptList) {
        Write-Host "    $($s.Id) - $($s.Name)" -ForegroundColor Yellow
    }
    Write-Host ""
    $confirm = Read-Host "  Type YES to confirm uninstall (or anything else to cancel)"
    $isConfirmed = $confirm -eq "YES"
    if (-not $isConfirmed) {
        Write-Log $logMessages.messages.uninstallCancelled -Level "info"
        return
    }

    # Execute uninstall sequence (reverse order)
    Write-Log ($logMessages.messages.uninstallStarting -replace '\{count\}', $scriptList.Count) -Level "info"
    $results = Invoke-UninstallSequence -ScriptList $scriptList -ScriptsRoot $scriptsRoot -LogMessages $logMessages

    # Summary
    Show-Summary -Results $results -LogMessages $logMessages
    Write-Log $logMessages.messages.uninstallComplete -Level "success"

    Save-ResolvedData -ScriptFolder "12-install-all-dev-tools" -Data @{
        action    = "uninstall"
        results   = $results
        timestamp = (Get-Date -Format "o")
    }
    return
}

# ==============================================================================
#  MODE A: Flag-based (non-interactive) or -Defaults
# ==============================================================================
$hasFilter = $Skip -or $Only
if ($hasFilter -or $All -or $DryRun -or $Defaults) {
    # With -Defaults, use all defaults for dev dir and env vars
    $hasPathParam = -not [string]::IsNullOrWhiteSpace($Path)
    if ($hasPathParam) {
        $env:DEV_DIR = $Path
        $devDir = $Path
        Write-Log "Using user-specified dev directory: $devDir" -Level "info"
    } elseif ($Defaults) {
        Invoke-Questionnaire -Mode "alldev" -Config $config -LogMessages $logMessages -UseDefaults
        $devDir = $env:DEV_DIR
    } else {
        Write-Log $logMessages.messages.resolvingDevDir -Level "info"
        $devDir = Resolve-DevDir -Config $config.devDir
        $env:DEV_DIR = $devDir
        Write-Log ($logMessages.messages.devDirResolved -replace '\{path\}', $devDir) -Level "success"
    }
    Initialize-DevDir -Path $devDir

    # If -Defaults without -Only/-Skip, default to alldev
    $scriptList = if ($Defaults -and -not $hasFilter) {
        Get-ScriptListForMode -Mode "alldev" -Config $config
    } else {
        Resolve-ScriptList -Config $config -Skip $Skip -Only $Only
    }

    # Dry run
    if ($DryRun) {
        Show-DryRun -ScriptList $scriptList -LogMessages $logMessages
        return
    }

    # Run
    $results = Invoke-ScriptSequence -ScriptList $scriptList -ScriptsRoot $scriptsRoot -LogMessages $logMessages -Skip $Skip
    Show-Summary -Results $results -LogMessages $logMessages
    Write-Log $logMessages.messages.allComplete -Level "success"

    Save-ResolvedData -ScriptFolder "12-install-all-dev-tools" -Data @{
        devDir    = $devDir
        results   = $results
        defaults  = [bool]$Defaults
        timestamp = (Get-Date -Format "o")
    }
    return
}

# ==============================================================================
#  MODE B: Interactive (front-loaded questions, then unattended execution)
# ==============================================================================
while ($true) {
    # -- Step 1: Quick menu ────────────────────────────────────────────────────
    $mode = Show-QuickMenu -LogMessages $logMessages

    $isQuit = $mode -eq "quit"
    if ($isQuit) {
        Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
        break
    }

    $isUninstallMode = $mode -eq "uninstall"
    if ($isUninstallMode) {
        # Delegate to uninstall flow via recursive call
        $fullList = Resolve-ScriptList -Config $config -Skip "" -Only ""
        $groups   = if ($config.groups) { $config.groups } else { $null }

        Write-Host ""
        Write-Log $logMessages.messages.uninstallMenuTitle -Level "warn"
        $selected = Show-InteractiveMenu -ScriptList $fullList -LogMessages $logMessages -Groups $groups

        $isUserQuit = $null -eq $selected
        if ($isUserQuit) {
            Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
            continue
        }

        $hasNoSelection = $selected.Count -eq 0
        if ($hasNoSelection) {
            Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
            continue
        }

        # Confirmation
        Write-Host ""
        Write-Log ($logMessages.messages.uninstallConfirmPrompt -replace '\{count\}', $selected.Count) -Level "warn"
        foreach ($s in $selected) {
            Write-Host "    $($s.Id) - $($s.Name)" -ForegroundColor Yellow
        }
        Write-Host ""
        $confirm = Read-Host "  Type YES to confirm uninstall (or anything else to cancel)"
        $isConfirmed = $confirm -eq "YES"
        if (-not $isConfirmed) {
            Write-Log $logMessages.messages.uninstallCancelled -Level "info"
            continue
        }

        Write-Log ($logMessages.messages.uninstallStarting -replace '\{count\}', $selected.Count) -Level "info"
        $results = Invoke-UninstallSequence -ScriptList $selected -ScriptsRoot $scriptsRoot -LogMessages $logMessages
        Show-Summary -Results $results -LogMessages $logMessages
        Write-Log $logMessages.messages.uninstallComplete -Level "success"
        continue
    }

    $isCustom = $mode -eq "custom"
    if ($isCustom) {
        # Custom: show the full interactive checkbox menu
        $fullList = Resolve-ScriptList -Config $config -Skip "" -Only ""
        $groups   = if ($config.groups) { $config.groups } else { $null }

        $scriptList = Show-InteractiveMenu -ScriptList $fullList -LogMessages $logMessages -Groups $groups

        $isUserQuit = $null -eq $scriptList
        if ($isUserQuit) {
            Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
            continue
        }

        $hasNoSelection = $scriptList.Count -eq 0
        if ($hasNoSelection) {
            Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
            continue
        }
    } else {
        # alldev or alldev+db: build list from mode
        $scriptList = Get-ScriptListForMode -Mode $mode -Config $config
    }

    # -- Step 2: Front-load all questions ──────────────────────────────────────
    $hasPathParam = -not [string]::IsNullOrWhiteSpace($Path)
    if ($hasPathParam) {
        $env:DEV_DIR = $Path
    }
    Invoke-Questionnaire -Mode $mode -Config $config -LogMessages $logMessages -UseDefaults:$Defaults

    # Dev dir is now set in $env:DEV_DIR by the questionnaire (or -Path override)
    $devDir = $env:DEV_DIR
    Initialize-DevDir -Path $devDir

    # -- Step 3: Run scripts unattended ────────────────────────────────────────
    Write-Log ($logMessages.messages.menuRunning -replace '\{count\}', $scriptList.Count) -Level "info"

    $results = Invoke-ScriptSequence -ScriptList $scriptList -ScriptsRoot $scriptsRoot -LogMessages $logMessages -Skip $Skip

    # -- Step 4: Summary ──────────────────────────────────────────────────────
    Show-Summary -Results $results -LogMessages $logMessages
    Write-Log $logMessages.messages.allComplete -Level "success"

    Save-ResolvedData -ScriptFolder "12-install-all-dev-tools" -Data @{
        mode      = $mode
        devDir    = $devDir
        results   = $results
        timestamp = (Get-Date -Format "o")
    }

    # Loop back
    Write-Host ""
    Write-Log $logMessages.messages.menuLoopBack -Level "info"
}

} catch {
    Write-Log "Unhandled error: $_" -Level "error"
    Write-Log "Stack: $($_.ScriptStackTrace)" -Level "error"
} finally {
    # -- Save log (always runs, even on crash) --
    $hasAnyErrors = $script:_LogErrors.Count -gt 0
    Save-LogFile -Status $(if ($hasAnyErrors) { "fail" } else { "ok" })
}
