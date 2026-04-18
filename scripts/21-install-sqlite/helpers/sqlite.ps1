# --------------------------------------------------------------------------
#  Helper -- SQLite installer
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

function Get-SqliteVersion {
    param(
        [PSCustomObject]$DbConfig
    )

    $version = ""
    try {
        $version = & $DbConfig.verifyCommand $DbConfig.versionFlag 2>&1 | Select-Object -First 1
    } catch {
        $version = "(version check failed)"
    }

    return "$version".Trim()
}

function Save-SqliteResolvedState {
    param(
        [string]$Version
    )

    Save-ResolvedData -ScriptFolder "21-install-sqlite" -Data @{
        version    = $Version
        resolvedAt = (Get-Date -Format "o")
        resolvedBy = $env:USERNAME
    }
}

function Install-SqliteBrowser {
    param(
        [PSCustomObject]$BrowserConfig,
        $LogMessages
    )

    $hasBrowserConfig = $null -ne $BrowserConfig
    $isBrowserConfigMissing = -not $hasBrowserConfig
    if ($isBrowserConfigMissing) {
        return $true
    }

    $isBrowserDisabled = -not $BrowserConfig.enabled
    if ($isBrowserDisabled) {
        return $true
    }

    $browserName = $BrowserConfig.name
    Write-Log ($LogMessages.messages.checkingBrowser -replace '\{name\}', $browserName) -Level "info"

    $isBrowserReady = Install-ChocoPackage -PackageName $BrowserConfig.chocoPackage
    $hasBrowserFailed = -not $isBrowserReady
    if ($hasBrowserFailed) {
        Write-Log ($LogMessages.messages.browserInstallFailed -replace '\{name\}', $browserName) -Level "error"
        return $false
    }

    Write-Log ($LogMessages.messages.browserReady -replace '\{name\}', $browserName) -Level "success"
    return $true
}

function Install-Sqlite {
    <#
    .SYNOPSIS
        Installs SQLite and verifies the installation.
        Returns $true on success, $false on failure.
    #>
    param(
        [PSCustomObject]$DbConfig,
        $LogMessages,
        [string]$InstallPath = ""
    )

    $isDisabled = -not $DbConfig.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.disabled -Level "info"
        return $true
    }

    Write-Log $LogMessages.messages.checking -Level "info"

    $cmd = Get-Command $DbConfig.verifyCommand -ErrorAction SilentlyContinue
    $isSqliteReady = $null -ne $cmd

    if ($isSqliteReady) {
        $version = Get-SqliteVersion -DbConfig $DbConfig
        Write-Log ($LogMessages.messages.found -replace '\{version\}', $version) -Level "success"
        Save-SqliteResolvedState -Version $version
    } else {
        Write-Log $LogMessages.messages.notFound -Level "info"
        Write-Log $LogMessages.messages.installing -Level "info"

        # Build install args for custom path
        $chocoArgs = @()

        $isInstalled = Install-ChocoPackage -PackageName $DbConfig.chocoPackage -ExtraArgs $chocoArgs
        $hasInstallFailed = -not $isInstalled
        if ($hasInstallFailed) {
            Write-Log ($LogMessages.messages.installFailed -replace '\{error\}', "Install returned failure") -Level "error"
            return $false
        }

        # Refresh PATH
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

        $cmd = Get-Command $DbConfig.verifyCommand -ErrorAction SilentlyContinue
        $isSqliteReady = $null -ne $cmd
        if ($isSqliteReady) {
            $version = Get-SqliteVersion -DbConfig $DbConfig
            Write-Log ($LogMessages.messages.installSuccess -replace '\{version\}', $version) -Level "success"
            Save-SqliteResolvedState -Version $version
        } else {
            Write-Log $LogMessages.messages.notInPath -Level "warn"
            return $false
        }
    }

    $isBrowserReady = Install-SqliteBrowser -BrowserConfig $DbConfig.browser -LogMessages $LogMessages
    $hasBrowserFailed = -not $isBrowserReady
    if ($hasBrowserFailed) {
        return $false
    }

    return $true
}

function Uninstall-Sqlite {
    <#
    .SYNOPSIS
        Full SQLite uninstall: choco uninstall, purge tracking.
    #>
    param(
        $DbConfig,
        $LogMessages
    )

    $packageName = $DbConfig.chocoPackage

    # 1. Uninstall via Chocolatey
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "SQLite") -Level "info"
    $isUninstalled = Uninstall-ChocoPackage -PackageName $packageName
    if ($isUninstalled) {
        Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "SQLite") -Level "success"
    } else {
        Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "SQLite") -Level "error"
    }

    # 2. Remove tracking records
    Remove-InstalledRecord -Name "sqlite"
    Remove-ResolvedData -ScriptFolder "21-install-sqlite"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
