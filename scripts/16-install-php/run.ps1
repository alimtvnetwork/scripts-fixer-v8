# --------------------------------------------------------------------------
#  Script 16 -- Install PHP (+ phpMyAdmin)
#  Supports 3 modes via -Mode parameter:
#    php+phpmyadmin  (default) -- PHP + phpMyAdmin
#    php-only                  -- PHP only
#    phpmyadmin-only           -- phpMyAdmin only
# --------------------------------------------------------------------------
param(
    [Parameter(Position = 0)]
    [string]$Command = "all",

    [Parameter(Position = 1)]
    [string]$Path,

    [switch]$Help,
    [ValidateSet("php+phpmyadmin", "php-only", "phpmyadmin-only")]
    [string]$Mode = ""
)

# -- Resolve mode: param > env var > default -----------------------------------
if ([string]::IsNullOrWhiteSpace($Mode)) {
    $envMode = $env:PHP_MODE
    $hasEnvMode = -not [string]::IsNullOrWhiteSpace($envMode)
    if ($hasEnvMode) {
        $Mode = $envMode
    } else {
        $Mode = "php+phpmyadmin"
    }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir = Join-Path (Split-Path -Parent $scriptDir) "shared"

$script:ScriptDir = $scriptDir

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "choco-utils.ps1")
. (Join-Path $sharedDir "installed.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\php.ps1")

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
    return
}

# -- Uninstall check -----------------------------------------------------------
$isUninstall = $Command.ToLower() -eq "uninstall"
if ($isUninstall) {
    Uninstall-Php -Config $config -LogMessages $logMessages
    return
}

# -- Mode announcement ---------------------------------------------------------
$modeLabel = switch ($Mode) {
    "php+phpmyadmin"  { "PHP + phpMyAdmin (install both)" }
    "php-only"        { "PHP only (no phpMyAdmin)" }
    "phpmyadmin-only" { "phpMyAdmin only (no PHP install)" }
}
Write-Log "Mode: $modeLabel" -Level "info"
Write-Host ""

# -- Install PHP ---------------------------------------------------------------
$phpOk = $true
$isPhpNeeded = $Mode -ne "phpmyadmin-only"
if ($isPhpNeeded) {
    $phpOk = Install-Php -Config $config.php -LogMessages $logMessages
} else {
    Write-Log "Skipping PHP installation (phpmyadmin-only mode)" -Level "info"
}

# -- Install phpMyAdmin --------------------------------------------------------
$pmaOk = $true
$isPmaNeeded = $Mode -ne "php-only"
if ($isPmaNeeded) {
    $pmaOk = Install-PhpMyAdmin -PmaConfig $config.phpmyadmin -LogMessages $logMessages
} else {
    Write-Log $logMessages.messages.pmaSkipped -Level "info"
}

# -- Summary -------------------------------------------------------------------
$isAllGood = $phpOk -and $pmaOk
if ($isAllGood) {
    Write-Log $logMessages.messages.setupComplete -Level "success"
} else {
    Write-Log $logMessages.messages.completedWithWarnings -Level "warn"
}

} catch {
    Write-Log "Unhandled error: $_" -Level "error"
    Write-Log "Stack: $($_.ScriptStackTrace)" -Level "error"
} finally {
    $hasAnyErrors = $script:_LogErrors.Count -gt 0
    Save-LogFile -Status $(if ($hasAnyErrors) { "fail" } else { "ok" })
}
