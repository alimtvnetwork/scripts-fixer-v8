# --------------------------------------------------------------------------
#  Helper -- Neo4j installer
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

function Install-Neo4J {
    <#
    .SYNOPSIS
        Installs Neo4j and verifies the installation.
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

    $cmd = Get-Command $DbConfig.verifyCommand -ErrorAction SilentlyContinue
    if ($cmd) {
        $version = ""
        try {
            $version = & $DbConfig.verifyCommand $DbConfig.versionFlag 2>&1 | Select-Object -First 1
        } catch { $version = "(version check failed)" }

        Write-Log ($LogMessages.messages.found -replace '\{version\}', $version) -Level "success"

        Save-ResolvedData -ScriptFolder "26-install-neo4j" -Data @{
            version    = "$version".Trim()
            resolvedAt = (Get-Date -Format "o")
            resolvedBy = $env:USERNAME
        }

        return $true
    }

    Write-Log $LogMessages.messages.notFound -Level "info"
    Write-Log $LogMessages.messages.installing -Level "info"
    # Build install args (system default -- custom directory is Chocolatey Business only)
    $chocoArgs = @()

    # Install
    $isInstalled = $false
    $isInstalled = Install-ChocoPackage -PackageName $DbConfig.chocoPackage -ExtraArgs $chocoArgs

    $hasInstallFailed = -not $isInstalled
    if ($hasInstallFailed) {
        Write-Log ($LogMessages.messages.installFailed -replace '\{error\}', "Install returned failure") -Level "error"
        return $false
    }

    # Refresh PATH
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    $cmd = Get-Command $DbConfig.verifyCommand -ErrorAction SilentlyContinue
    if ($cmd) {
        $version = ""
        try {
            $version = & $DbConfig.verifyCommand $DbConfig.versionFlag 2>&1 | Select-Object -First 1
        } catch { $version = "(version check failed)" }

        Write-Log ($LogMessages.messages.installSuccess -replace '\{version\}', $version) -Level "success"

        Save-ResolvedData -ScriptFolder "26-install-neo4j" -Data @{
            version    = "$version".Trim()
            resolvedAt = (Get-Date -Format "o")
            resolvedBy = $env:USERNAME
        }

        return $true
    } else {
        Write-Log $LogMessages.messages.notInPath -Level "warn"
        return $false
    }
}

function Uninstall-Neo4J {
    <#
    .SYNOPSIS
        Full Neo4j uninstall: choco uninstall, purge tracking.
    #>
    param(
        $DbConfig,
        $LogMessages
    )

    $packageName = $DbConfig.chocoPackage

    # 1. Uninstall via Chocolatey
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "Neo4j") -Level "info"
    $isUninstalled = Uninstall-ChocoPackage -PackageName $packageName
    if ($isUninstalled) {
        Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "Neo4j") -Level "success"
    } else {
        Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "Neo4j") -Level "error"
    }

    # 2. Remove tracking records
    Remove-InstalledRecord -Name "neo4j"
    Remove-ResolvedData -ScriptFolder "26-install-neo4j"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
