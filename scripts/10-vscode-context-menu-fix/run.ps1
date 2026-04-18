# --------------------------------------------------------------------------
#  Script 10 -- VS Code Context Menu Fix
#  Restores "Open with Code" to the Windows right-click context menu.
# --------------------------------------------------------------------------
param(
    [Parameter(Position = 0)]
    [string]$Command = "all",

    [Parameter(Position = 1)]
    [string]$Path,

    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir = Join-Path (Split-Path -Parent $scriptDir) "shared"

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "installed.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\registry.ps1")

# -- Load config & log messages -----------------------------------------------
$config      = Import-JsonConfig (Join-Path $scriptDir "config.json")
$logMessages = Import-JsonConfig (Join-Path $scriptDir "log-messages.json")

# -- Help ---------------------------------------------------------------------
if ($Help -or $Command -eq "--help") {
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

# -- Disabled check ------------------------------------------------------------
$isDisabled = -not $config.enabled
if ($isDisabled) {
    Write-Log $logMessages.messages.scriptDisabled -Level "warn"
    return
}

# -- Assert admin --------------------------------------------------------------
$hasAdminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isNotAdmin = -not $hasAdminRights
if ($isNotAdmin) {
    Write-Log $logMessages.messages.notAdmin -Level "error"
    Write-Host $script:SharedLogMessages.messages.adminTip -ForegroundColor Yellow
    return
}

# -- Uninstall check -----------------------------------------------------------
$isUninstall = $Command.ToLower() -eq "uninstall"
if ($isUninstall) {
    Uninstall-VsCodeContextMenu -Config $config -LogMessages $logMessages
    return
}

# -- Process editions ----------------------------------------------------------
$installType     = $config.installationType
$enabledEditions = $config.enabledEditions
$isAllSuccessful = $true

Write-Log ($logMessages.messages.installTypePref -replace '\{type\}', $installType) -Level "info"
Write-Log ($logMessages.messages.enabledEditions -replace '\{editions\}', ($enabledEditions -join ', ')) -Level "info"

foreach ($editionName in $enabledEditions) {
    $edition = $config.editions.$editionName

    $isEditionMissing = -not $edition
    if ($isEditionMissing) {
        Write-Log ($logMessages.messages.unknownEdition -replace '\{name\}', $editionName) -Level "warn"
        $isAllSuccessful = $false
        continue
    }

    $result = Invoke-Edition `
        -Edition     $edition `
        -EditionName $editionName `
        -InstallType $installType `
        -ScriptDir   $scriptDir `
        -Steps       @{
            detectInstall = $logMessages.messages.detectInstall
            regFile       = $logMessages.messages.regFile
            regDir        = $logMessages.messages.regDir
            regBg         = $logMessages.messages.regBg
            verify        = $logMessages.messages.verify
        }

    $hasFailed = -not $result
    if ($hasFailed) { $isAllSuccessful = $false }
}

# -- Summary -------------------------------------------------------------------
if ($isAllSuccessful) {
    Write-Log $logMessages.messages.done -Level "success"
} else {
    Write-Log $logMessages.messages.completedWithWarnings -Level "warn"
}

# -- Save resolved state -------------------------------------------------------
Save-ResolvedData -ScriptFolder "10-vscode-context-menu-fix" -Data @{
    editions  = ($enabledEditions -join ',')
    timestamp = (Get-Date -Format "o")
}

# -- Save log ------------------------------------------------------------------

} catch {
    Write-Log "Unhandled error: $_" -Level "error"
    Write-Log "Stack: $($_.ScriptStackTrace)" -Level "error"
} finally {
    # -- Save log (always runs, even on crash) --
    $hasAnyErrors = $script:_LogErrors.Count -gt 0
    Save-LogFile -Status $(if ($hasAnyErrors) { "fail" } else { "ok" })
}