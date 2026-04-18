# --------------------------------------------------------------------------
#  Docker Desktop helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Test-Wsl2 {
    param(
        $Config,
        $LogMessages
    )

    $isWsl2CheckDisabled = -not $Config.wsl2.ensureEnabled
    if ($isWsl2CheckDisabled) { return }

    Write-Log $LogMessages.messages.wsl2Checking -Level "info"

    try {
        $wslOutput = & wsl --status 2>$null
        $isWslAvailable = $LASTEXITCODE -eq 0
        if ($isWslAvailable) {
            Write-Log $LogMessages.messages.wsl2Enabled -Level "success"
        } else {
            Write-Log $LogMessages.messages.wsl2NotEnabled -Level "warn"
        }
    } catch {
        Write-Log $LogMessages.messages.wsl2NotEnabled -Level "warn"
    }
}

function Install-DockerDesktop {
    param(
        $Config,
        $LogMessages
    )

    $packageName = $Config.chocoPackageName

    $existing = Get-Command docker -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = try { & docker --version 2>$null } catch { $null }
        $hasVersion = -not [string]::IsNullOrWhiteSpace($currentVersion)

        # Check .installed/ tracking
        if ($hasVersion) {
            $isAlreadyTracked = Test-AlreadyInstalled -Name "docker" -CurrentVersion $currentVersion
            if ($isAlreadyTracked) {
                Write-Log ($LogMessages.messages.dockerAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"
                return
            }
        }

        Write-Log ($LogMessages.messages.dockerAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($Config.alwaysUpgradeToLatest) {
            try {
                Upgrade-ChocoPackage -PackageName $packageName
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $newVersion = try { & docker --version 2>$null } catch { $null }
                $isVersionEmpty = [string]::IsNullOrWhiteSpace($newVersion)
                if ($isVersionEmpty) { $newVersion = "(version pending)" }
                Write-Log ($LogMessages.messages.dockerUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
                Save-InstalledRecord -Name "docker" -Version "$newVersion".Trim()
            } catch {
                Write-Log "Docker Desktop upgrade failed: $_" -Level "error"
                Save-InstalledError -Name "docker" -ErrorMessage "$_"
            }
        }
    }
    else {
        Write-Log $LogMessages.messages.dockerNotFound -Level "info"
        try {
            Install-ChocoPackage -PackageName $packageName

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            $installedVersion = try { & docker --version 2>$null } catch { "(reboot required)" }
            Write-Log ($LogMessages.messages.dockerInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
            Write-Log $LogMessages.messages.rebootRequired -Level "warn"
            Save-InstalledRecord -Name "docker" -Version $installedVersion
        } catch {
            Write-Log "Docker Desktop install failed: $_" -Level "error"
            Save-InstalledError -Name "docker" -ErrorMessage "$_"
        }
    }

    # Show compose version
    $composeVersion = try { & docker compose version 2>$null } catch { $null }
    $hasCompose = -not [string]::IsNullOrWhiteSpace($composeVersion)
    if ($hasCompose) {
        Write-Log ($LogMessages.messages.composeVersion -replace '\{version\}', $composeVersion) -Level "info"
    }
}

function Test-DockerDaemon {
    param(
        $Config,
        $LogMessages
    )

    $isVerifyDisabled = -not $Config.postInstall.verifyDaemon
    if ($isVerifyDisabled) { return }

    try {
        & docker info 2>$null | Out-Null
        $isDaemonRunning = $LASTEXITCODE -eq 0
        if ($isDaemonRunning) {
            Write-Log $LogMessages.messages.daemonRunning -Level "success"
        } else {
            Write-Log $LogMessages.messages.daemonNotRunning -Level "warn"
        }
    } catch {
        Write-Log $LogMessages.messages.daemonNotRunning -Level "warn"
    }
}

function Update-DockerPath {
    param(
        $Config,
        $LogMessages
    )

    $isPathUpdateDisabled = -not $Config.path.updateUserPath
    if ($isPathUpdateDisabled) { return }

    $dockerExe = Get-Command docker -ErrorAction SilentlyContinue
    $isDockerMissing = -not $dockerExe
    if ($isDockerMissing) { return }

    $dockerDir = Split-Path -Parent $dockerExe.Source

    $isAlreadyInPath = Test-InPath -Directory $dockerDir
    if ($isAlreadyInPath) {
        Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $dockerDir) -Level "info"
    } else {
        Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $dockerDir) -Level "info"
        Add-ToUserPath -Directory $dockerDir
    }
}

function Uninstall-Docker {
    param(
        $Config,
        $LogMessages
    )

    Write-Log $LogMessages.messages.uninstalling -Level "info"

    $isUninstalled = Uninstall-ChocoPackage -PackageName $Config.chocoPackageName
    if ($isUninstalled) {
        Write-Log $LogMessages.messages.uninstallSuccess -Level "success"
    } else {
        Write-Log $LogMessages.messages.uninstallFailed -Level "error"
    }

    Remove-InstalledRecord -Name "docker"
    Remove-ResolvedData -ScriptFolder "45-install-docker"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
