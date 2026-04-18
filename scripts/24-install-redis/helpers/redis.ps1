# --------------------------------------------------------------------------
#  Helper -- Redis installer
#  Fallback chain: redis-64 -> redis (tporadowski) -> manual guidance
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}
$_chocoUtilsPath = Join-Path $_sharedDir "choco-utils.ps1"
if ((Test-Path $_chocoUtilsPath) -and -not (Get-Command Install-ChocoPackage -ErrorAction SilentlyContinue)) {
    . $_chocoUtilsPath
}

function Install-Redis {
    <#
    .SYNOPSIS
        Installs Redis with a fallback chain.
        Tries redis-64 (Memurai-based) first, then falls back to
        tporadowski/redis if the primary fails (common MSI 1603 issue).
        Returns $true on success, $false on failure.
    #>
    param(
        [PSCustomObject]$DbConfig,
        $LogMessages,
        [string]$InstallPath = ""
    )

    $name = $DbConfig.name

    $isDisabled = -not $DbConfig.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.disabled -Level "info"
        return $true
    }

    Write-Log $LogMessages.messages.checking -Level "info"

    # -- Already installed? ----------------------------------------------------
    $cmd = Get-Command $DbConfig.verifyCommand -ErrorAction SilentlyContinue
    if ($cmd) {
        $version = Get-RedisVersion -DbConfig $DbConfig
        Write-Log ($LogMessages.messages.found -replace '\{version\}', $version) -Level "success"
        Save-RedisResolved -Version $version
        return $true
    }

    # -- Try primary package (redis-64 / Memurai) ------------------------------
    Write-Log $LogMessages.messages.notFound -Level "info"
    Write-Log $LogMessages.messages.installing -Level "info"

    $isInstalled = Install-ChocoPackage -PackageName $DbConfig.chocoPackage -ExtraArgs @()

    # -- Fallback: try alternative package if primary failed -------------------
    $hasPrimaryFailed = -not $isInstalled
    if ($hasPrimaryFailed) {
        $hasFallback = $null -ne $DbConfig.fallbackPackage -and $DbConfig.fallbackPackage -ne ""
        if ($hasFallback) {
            $fallbackPkg = $DbConfig.fallbackPackage
            Write-Log ($LogMessages.messages.primaryFailed -replace '\{package\}', $DbConfig.chocoPackage) -Level "warn"
            Write-Log ($LogMessages.messages.tryingFallback -replace '\{package\}', $fallbackPkg) -Level "info"

            $isInstalled = Install-ChocoPackage -PackageName $fallbackPkg -ExtraArgs @()

            $hasFallbackFailed = -not $isInstalled
            if ($hasFallbackFailed) {
                Write-Log ($LogMessages.messages.fallbackFailed -replace '\{package\}', $fallbackPkg) -Level "error"
                Write-Log $LogMessages.messages.manualHint -Level "info"
                return $false
            }
        } else {
            Write-Log ($LogMessages.messages.installFailed -replace '\{error\}', "Install returned failure") -Level "error"
            Write-Log $LogMessages.messages.manualHint -Level "info"
            return $false
        }
    }

    # -- Refresh PATH and verify -----------------------------------------------
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    $cmd = Get-Command $DbConfig.verifyCommand -ErrorAction SilentlyContinue
    if ($cmd) {
        $version = Get-RedisVersion -DbConfig $DbConfig
        Write-Log ($LogMessages.messages.installSuccess -replace '\{version\}', $version) -Level "success"
        Save-RedisResolved -Version $version
        return $true
    } else {
        Write-Log $LogMessages.messages.notInPath -Level "warn"
        Write-Log $LogMessages.messages.manualHint -Level "info"
        return $false
    }
}

# -- Internal helpers ----------------------------------------------------------

function Get-RedisVersion {
    param([PSCustomObject]$DbConfig)
    try {
        $version = & $DbConfig.verifyCommand $DbConfig.versionFlag 2>&1 | Select-Object -First 1
        return "$version"
    } catch {
        return "(version check failed)"
    }
}

function Save-RedisResolved {
    param([string]$Version)
    Save-ResolvedData -ScriptFolder "24-install-redis" -Data @{
        version    = "$Version".Trim()
        resolvedAt = (Get-Date -Format "o")
        resolvedBy = $env:USERNAME
    }
}

function Uninstall-Redis {
    <#
    .SYNOPSIS
        Full Redis uninstall: choco uninstall, purge tracking.
    #>
    param(
        $DbConfig,
        $LogMessages
    )

    $packageName = $DbConfig.chocoPackage

    # 1. Uninstall via Chocolatey
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "Redis") -Level "info"
    $isUninstalled = Uninstall-ChocoPackage -PackageName $packageName
    if ($isUninstalled) {
        Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "Redis") -Level "success"
    } else {
        Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "Redis") -Level "error"
    }

    # 2. Remove tracking records
    Remove-InstalledRecord -Name "redis"
    Remove-ResolvedData -ScriptFolder "24-install-redis"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
