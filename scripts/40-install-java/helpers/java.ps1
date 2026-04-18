# --------------------------------------------------------------------------
#  Java (OpenJDK) helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-Java {
    param(
        $Config,
        $LogMessages,
        [string]$Version
    )

    # Resolve version
    $hasVersion = -not [string]::IsNullOrWhiteSpace($Version)
    if (-not $hasVersion) {
        $Version = $Config.defaultVersion
    }

    # Validate version
    $availableVersions = @($Config.availableVersions)
    $isValidVersion = $Version -in $availableVersions
    if (-not $isValidVersion) {
        $versionList = $availableVersions -join ", "
        Write-Log ($LogMessages.messages.invalidVersion -replace '\{version\}', $Version -replace '\{versions\}', $versionList) -Level "error"
        return
    }

    # Resolve choco package name
    $packageName = $Config.chocoPackages.$Version
    Write-Log ($LogMessages.messages.installingVersion -replace '\{version\}', $Version -replace '\{package\}', $packageName) -Level "info"

    $existing = Get-Command java -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = try { & java -version 2>&1 | Select-Object -First 1 } catch { $null }
        $hasCurrentVersion = -not [string]::IsNullOrWhiteSpace($currentVersion)

        # Check .installed/ tracking -- skip if version matches
        if ($hasCurrentVersion) {
            $isAlreadyTracked = Test-AlreadyInstalled -Name "java-$Version" -CurrentVersion "$currentVersion"
            if ($isAlreadyTracked) {
                Write-Log ($LogMessages.messages.javaAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"
                return
            }
        }

        Write-Log ($LogMessages.messages.javaAlreadyInstalled -replace '\{version\}', $(if ($hasCurrentVersion) { $currentVersion } else { "(version unknown)" })) -Level "info"

        if ($Config.alwaysUpgradeToLatest) {
            try {
                Upgrade-ChocoPackage -PackageName $packageName
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $newVersion = try { & java -version 2>&1 | Select-Object -First 1 } catch { $null }
                Write-Log ($LogMessages.messages.javaUpgradeSuccess -replace '\{version\}', $(if ($newVersion) { $newVersion } else { "unknown" })) -Level "success"
                Save-InstalledRecord -Name "java-$Version" -Version $(if ($newVersion) { $newVersion } else { "unknown" })
            } catch {
                Write-Log "Java upgrade failed: $_" -Level "error"
                Save-InstalledError -Name "java-$Version" -ErrorMessage "$_"
            }
        }
    }
    else {
        Write-Log $LogMessages.messages.javaNotFound -Level "info"
        try {
            Install-ChocoPackage -PackageName $packageName

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            $installedVersion = try { & java -version 2>&1 | Select-Object -First 1 } catch { $null }
            Write-Log ($LogMessages.messages.javaInstallSuccess -replace '\{version\}', $(if ($installedVersion) { $installedVersion } else { "unknown" })) -Level "success"
            Save-InstalledRecord -Name "java-$Version" -Version $(if ($installedVersion) { $installedVersion } else { "unknown" })
        } catch {
            Write-Log "Java install failed: $_" -Level "error"
            Save-InstalledError -Name "java-$Version" -ErrorMessage "$_"
        }
    }
}

function Set-JavaHome {
    param(
        $Config,
        $LogMessages,
        [string]$DevDir
    )

    $isSetJavaHomeDisabled = -not $Config.env.setJavaHome
    if ($isSetJavaHomeDisabled) { return }

    # Try to find Java install path
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    $hasJavaCmd = $null -ne $javaCmd
    if (-not $hasJavaCmd) { return }

    # Resolve JAVA_HOME from java.exe location
    $javaExePath = $javaCmd.Source
    $javaBinDir = Split-Path -Parent $javaExePath
    $javaHomeDir = Split-Path -Parent $javaBinDir

    $currentJavaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
    if ($currentJavaHome -eq $javaHomeDir) {
        Write-Log ($LogMessages.messages.javaHomeAlreadySet -replace '\{path\}', $javaHomeDir) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.settingJavaHome -replace '\{path\}', $javaHomeDir) -Level "info"
        [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHomeDir, "User")
        $env:JAVA_HOME = $javaHomeDir
        Write-Log ($LogMessages.messages.javaHomeSet -replace '\{path\}', $javaHomeDir) -Level "success"
    }
}

function Update-JavaPath {
    param(
        $Config,
        $LogMessages,
        [string]$DevDir
    )

    $isPathUpdateDisabled = -not $Config.path.updateUserPath
    if ($isPathUpdateDisabled) { return }

    $hasDevDir = -not [string]::IsNullOrWhiteSpace($DevDir)
    if (-not $hasDevDir) { return }

    $javaDir = Join-Path $DevDir $Config.devDirSubfolder

    # Ensure directory exists
    $isDirMissing = -not (Test-Path $javaDir)
    if ($isDirMissing) {
        New-Item -Path $javaDir -ItemType Directory -Force | Out-Null
    }

    $binDir = Join-Path $javaDir "bin"
    $isBinMissing = -not (Test-Path $binDir)
    if ($isBinMissing) {
        New-Item -Path $binDir -ItemType Directory -Force | Out-Null
    }

    $isAlreadyInPath = Test-InPath -Directory $binDir
    if ($isAlreadyInPath) {
        Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $binDir) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $binDir) -Level "info"
        Add-ToUserPath -Directory $binDir
    }
}

function Uninstall-Java {
    <#
    .SYNOPSIS
        Full Java uninstall: choco uninstall all versions, remove JAVA_HOME,
        remove from PATH, clean dev dir subfolder, purge tracking.
    #>
    param(
        $Config,
        $LogMessages,
        [string]$DevDir
    )

    # 1. Uninstall all Java packages via Chocolatey
    Write-Log ($LogMessages.messages.uninstallingJava) -Level "info"
    foreach ($prop in $Config.chocoPackages.PSObject.Properties) {
        $packageName = $prop.Value
        $isUninstalled = Uninstall-ChocoPackage -PackageName $packageName
        if ($isUninstalled) {
            Write-Log "Java package '$packageName' uninstalled" -Level "success"
        }
    }

    # 2. Remove JAVA_HOME environment variable
    $currentJavaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
    $hasJavaHome = -not [string]::IsNullOrWhiteSpace($currentJavaHome)
    if ($hasJavaHome) {
        Write-Log "Removing JAVA_HOME env var: $currentJavaHome" -Level "info"
        [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $null, "User")
        $env:JAVA_HOME = $null
    }

    # 3. Remove dev directory from PATH
    $javaDir = if ($DevDir) {
        Join-Path $DevDir $Config.devDirSubfolder
    } else {
        $null
    }

    $hasValidDir = -not [string]::IsNullOrWhiteSpace($javaDir)
    if ($hasValidDir) {
        $binDir = Join-Path $javaDir "bin"
        Remove-FromUserPath -Directory $binDir
    }

    # 4. Clean dev directory subfolder
    if ($hasValidDir -and (Test-Path $javaDir)) {
        Write-Log "Removing dev directory subfolder: $javaDir" -Level "info"
        Remove-Item -Path $javaDir -Recurse -Force
        Write-Log "Dev directory subfolder removed: $javaDir" -Level "success"
    }

    # 5. Remove tracking records for all versions
    foreach ($ver in $Config.availableVersions) {
        Remove-InstalledRecord -Name "java-$ver"
    }
    Remove-ResolvedData -ScriptFolder "40-install-java"

    Write-Log ($LogMessages.messages.javaUninstallComplete) -Level "success"
}
