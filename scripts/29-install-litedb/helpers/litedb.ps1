# --------------------------------------------------------------------------
#  Helper -- LiteDB installer
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

function Install-Litedb {
    <#
    .SYNOPSIS
        Installs LiteDB and verifies the installation.
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

        Save-ResolvedData -ScriptFolder "29-install-litedb" -Data @{
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
    try {
        $dotnetCmd = Get-Command "dotnet" -ErrorAction SilentlyContinue
        $hasDotnet = [bool]$dotnetCmd
        if ($hasDotnet) {
            & dotnet tool install -g LiteDB.Shell 2>&1 | Out-Null
            $isInstalled = $true
        } else {
            Write-Log ($LogMessages.messages.installFailed -replace '\{error\}', "dotnet CLI not found") -Level "error"
            return $false
        }
    } catch {
        Write-Log ($LogMessages.messages.installFailed -replace '\{error\}', $_.Exception.Message) -Level "error"
        return $false
    }

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

        Save-ResolvedData -ScriptFolder "29-install-litedb" -Data @{
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

function Uninstall-Litedb {
    <#
    .SYNOPSIS
        Full LiteDB uninstall: dotnet uninstall, purge tracking.
    #>
    param(
        $DbConfig,
        $LogMessages
    )

    # 1. Uninstall via dotnet tool
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "LiteDB") -Level "info"
    try {
        $output = & dotnet tool uninstall -g $DbConfig.dotnetPackage 2>&1
        Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "LiteDB") -Level "success"
    } catch {
        Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "LiteDB") -Level "error"
    }

    # 2. Remove tracking records
    Remove-InstalledRecord -Name "litedb"
    Remove-ResolvedData -ScriptFolder "29-install-litedb"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
