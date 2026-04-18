# --------------------------------------------------------------------------
#  .NET SDK helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-DotnetSdk {
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

    $existing = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = try { & dotnet --version 2>$null } catch { $null }
        $hasCurrentVersion = -not [string]::IsNullOrWhiteSpace($currentVersion)

        # Check .installed/ tracking -- skip if version matches
        if ($hasCurrentVersion) {
            $isAlreadyTracked = Test-AlreadyInstalled -Name "dotnet-$Version" -CurrentVersion $currentVersion
            if ($isAlreadyTracked) {
                Write-Log ($LogMessages.messages.dotnetAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"
                return
            }
        }

        Write-Log ($LogMessages.messages.dotnetAlreadyInstalled -replace '\{version\}', $(if ($hasCurrentVersion) { $currentVersion } else { "(version unknown)" })) -Level "info"

        if ($Config.alwaysUpgradeToLatest) {
            try {
                Upgrade-ChocoPackage -PackageName $packageName
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $newVersion = try { & dotnet --version 2>$null } catch { $null }
                Write-Log ($LogMessages.messages.dotnetUpgradeSuccess -replace '\{version\}', $(if ($newVersion) { $newVersion } else { "unknown" })) -Level "success"
                Save-InstalledRecord -Name "dotnet-$Version" -Version $(if ($newVersion) { $newVersion } else { "unknown" })
            } catch {
                Write-Log ".NET SDK upgrade failed: $_" -Level "error"
                Save-InstalledError -Name "dotnet-$Version" -ErrorMessage "$_"
            }
        }
    }
    else {
        Write-Log $LogMessages.messages.dotnetNotFound -Level "info"
        try {
            Install-ChocoPackage -PackageName $packageName

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            $installedVersion = try { & dotnet --version 2>$null } catch { $null }
            Write-Log ($LogMessages.messages.dotnetInstallSuccess -replace '\{version\}', $(if ($installedVersion) { $installedVersion } else { "unknown" })) -Level "success"
            Save-InstalledRecord -Name "dotnet-$Version" -Version $(if ($installedVersion) { $installedVersion } else { "unknown" })
        } catch {
            Write-Log ".NET SDK install failed: $_" -Level "error"
            Save-InstalledError -Name "dotnet-$Version" -ErrorMessage "$_"
        }
    }
}

function Update-DotnetPath {
    param(
        $Config,
        $LogMessages,
        [string]$DevDir
    )

    $isPathUpdateDisabled = -not $Config.path.updateUserPath
    if ($isPathUpdateDisabled) { return }

    $hasDevDir = -not [string]::IsNullOrWhiteSpace($DevDir)
    if (-not $hasDevDir) { return }

    $dotnetDir = Join-Path $DevDir $Config.devDirSubfolder

    # Ensure directory exists
    $isDirMissing = -not (Test-Path $dotnetDir)
    if ($isDirMissing) {
        New-Item -Path $dotnetDir -ItemType Directory -Force | Out-Null
    }

    $isAlreadyInPath = Test-InPath -Directory $dotnetDir
    if ($isAlreadyInPath) {
        Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $dotnetDir) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $dotnetDir) -Level "info"
        Add-ToUserPath -Directory $dotnetDir
    }
}

function Uninstall-DotnetSdk {
    <#
    .SYNOPSIS
        Full .NET SDK uninstall: choco uninstall all versions, remove from PATH,
        clean dev dir subfolder, purge tracking.
    #>
    param(
        $Config,
        $LogMessages,
        [string]$DevDir
    )

    # 1. Uninstall all .NET SDK packages via Chocolatey
    Write-Log ($LogMessages.messages.uninstallingDotnet) -Level "info"
    foreach ($prop in $Config.chocoPackages.PSObject.Properties) {
        $packageName = $prop.Value
        $isUninstalled = Uninstall-ChocoPackage -PackageName $packageName
        if ($isUninstalled) {
            Write-Log ".NET package '$packageName' uninstalled" -Level "success"
        }
    }

    # 2. Remove dev directory subfolder from PATH
    $dotnetDir = if ($DevDir) {
        Join-Path $DevDir $Config.devDirSubfolder
    } else {
        $null
    }

    $hasValidDir = -not [string]::IsNullOrWhiteSpace($dotnetDir)
    if ($hasValidDir) {
        Remove-FromUserPath -Directory $dotnetDir
    }

    # 3. Clean dev directory subfolder
    if ($hasValidDir -and (Test-Path $dotnetDir)) {
        Write-Log "Removing dev directory subfolder: $dotnetDir" -Level "info"
        Remove-Item -Path $dotnetDir -Recurse -Force
        Write-Log "Dev directory subfolder removed: $dotnetDir" -Level "success"
    }

    # 4. Remove tracking records for all versions
    foreach ($ver in $Config.availableVersions) {
        Remove-InstalledRecord -Name "dotnet-$ver"
    }
    Remove-ResolvedData -ScriptFolder "39-install-dotnet"

    Write-Log ($LogMessages.messages.dotnetUninstallComplete) -Level "success"
}
