# --------------------------------------------------------------------------
#  Helper -- Simple Sticky Notes installer
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

function Test-StickyNotesInstalled {
    # Check common install locations
    $defaultPaths = @(
        "$env:ProgramFiles\Simple Sticky Notes\SimpleSticky.exe",
        "${env:ProgramFiles(x86)}\Simple Sticky Notes\SimpleSticky.exe",
        "$env:LOCALAPPDATA\Simple Sticky Notes\SimpleSticky.exe"
    )
    foreach ($p in $defaultPaths) {
        $isPresent = Test-Path $p
        if ($isPresent) { return $true }
    }

    # Try Get-Command as fallback
    $cmd = Get-Command "SimpleSticky" -ErrorAction SilentlyContinue
    $isInPath = $null -ne $cmd
    if ($isInPath) { return $true }

    return $false
}

function Save-StickyNotesResolvedState {
    Save-ResolvedData -ScriptFolder "34-install-sticky-notes" -Data @{
        resolvedAt = (Get-Date -Format "o")
        resolvedBy = $env:USERNAME
    }
}

function Install-StickyNotes {
    <#
    .SYNOPSIS
        Installs Simple Sticky Notes via Chocolatey.
        Returns $true on success, $false on failure.
    #>
    param(
        [PSCustomObject]$StickyConfig,
        $LogMessages
    )

    $isDisabled = -not $StickyConfig.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.disabled -Level "info"
        return $true
    }

    Write-Log $LogMessages.messages.checking -Level "info"

    $isStickyReady = Test-StickyNotesInstalled
    if ($isStickyReady) {
        Write-Log $LogMessages.messages.found -Level "success"
        Save-StickyNotesResolvedState
        return $true
    }

    Write-Log $LogMessages.messages.notFound -Level "info"
    Write-Host ""
    Write-Log $LogMessages.messages.installing -Level "info"

    $isInstalled = Install-ChocoPackage -PackageName $StickyConfig.chocoPackage
    $hasInstallFailed = -not $isInstalled
    if ($hasInstallFailed) {
        Write-FileError -FilePath "$env:ProgramFiles\Simple Sticky Notes\SimpleSticky.exe" -Operation "resolve" -Reason "Chocolatey install returned failure for '$($StickyConfig.chocoPackage)'" -Module "Install-StickyNotes"
        Write-Log ($LogMessages.messages.installFailed -replace '\{error\}', "Install returned failure") -Level "error"
        return $false
    }

    # Refresh PATH
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    # Verify installation
    $verifyPaths = @(
        "$env:ProgramFiles\Simple Sticky Notes\SimpleSticky.exe",
        "${env:ProgramFiles(x86)}\Simple Sticky Notes\SimpleSticky.exe"
    )
    $installedPath = $null
    foreach ($p in $verifyPaths) {
        if (Test-Path $p) {
            $installedPath = $p
            break
        }
    }

    if ($installedPath) {
        Write-Log $LogMessages.messages.installSuccess -Level "success"
        Write-Log "Install target: $installedPath" -Level "success"
        Save-StickyNotesResolvedState

        # Save install record
        $version = "unknown"
        try { $version = (Get-Item $installedPath).VersionInfo.ProductVersion } catch { }
        Save-InstalledRecord -Name "sticky-notes" -Version $version -Method "chocolatey"
    } else {
        Write-Log $LogMessages.messages.notInPath -Level "warn"
        Save-StickyNotesResolvedState
    }

    return $true
}

function Set-StickyNotesDataFolder {
    <#
    .SYNOPSIS
        Redirects SSN data storage to a custom folder via directory symlink.
        Default SSN data lives in %APPDATA%\Simple Sticky Notes.
        This creates a symlink from that location to the configured path.
    #>
    param(
        [PSCustomObject]$DataFolderConfig,
        $LogMessages
    )

    $isDisabled = -not $DataFolderConfig.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.dataFolderSkipped -Level "info"
        return $true
    }

    $targetPath = $DataFolderConfig.path

    # Ensure target folder exists
    $isTargetMissing = -not (Test-Path $targetPath)
    if ($isTargetMissing) {
        if ($DataFolderConfig.createIfMissing) {
            try {
                New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
                Write-Log ($LogMessages.messages.dataFolderCreated -replace '\{path\}', $targetPath) -Level "success"
            } catch {
                Write-FileError -FilePath $targetPath -Operation "create" -Reason "$_" -Module "Set-StickyNotesDataFolder"
                Write-Log ($LogMessages.messages.dataFolderFailed -replace '\{error\}', "$_") -Level "error"
                return $false
            }
        } else {
            Write-FileError -FilePath $targetPath -Operation "resolve" -Reason "Custom data folder does not exist and createIfMissing is false" -Module "Set-StickyNotesDataFolder"
            Write-Log ($LogMessages.messages.dataFolderFailed -replace '\{error\}', "Target folder does not exist") -Level "error"
            return $false
        }
    } else {
        Write-Log ($LogMessages.messages.dataFolderExists -replace '\{path\}', $targetPath) -Level "info"
    }

    # SSN default data location
    $ssnDataDir = Join-Path $env:APPDATA "Simple Sticky Notes"

    # Check if already a symlink pointing to the right place
    $isExistingLink = (Test-Path $ssnDataDir) -and ((Get-Item $ssnDataDir).Attributes -band [System.IO.FileAttributes]::ReparsePoint)
    if ($isExistingLink) {
        $linkTarget = (Get-Item $ssnDataDir).Target
        $isCorrectTarget = $linkTarget -eq $targetPath
        if ($isCorrectTarget) {
            Write-Log ($LogMessages.messages.dataFolderAlreadyLinked -replace '\{path\}', $targetPath) -Level "info"
            return $true
        }
        # Wrong target -- remove and re-link
        Remove-Item $ssnDataDir -Force
    }

    # If SSN data dir exists as a real folder, move contents to target
    $isRealFolder = (Test-Path $ssnDataDir) -and -not $isExistingLink
    if ($isRealFolder) {
        $existingFiles = Get-ChildItem -Path $ssnDataDir -Recurse -Force
        $hasFiles = $existingFiles.Count -gt 0
        if ($hasFiles) {
            Copy-Item -Path "$ssnDataDir\*" -Destination $targetPath -Recurse -Force
        }
        Remove-Item $ssnDataDir -Recurse -Force
    }

    # Create symlink: %APPDATA%\Simple Sticky Notes -> D:\notes
    try {
        New-Item -ItemType SymbolicLink -Path $ssnDataDir -Target $targetPath -Force | Out-Null
        Write-Log ($LogMessages.messages.dataFolderSymlinked -replace '\{path\}', $targetPath) -Level "success"
        return $true
    } catch {
        Write-FileError -FilePath $ssnDataDir -Operation "symlink" -Reason "$_" -Module "Set-StickyNotesDataFolder"
        Write-Log ($LogMessages.messages.dataFolderFailed -replace '\{error\}', "$_") -Level "error"
        return $false
    }
}

function Uninstall-StickyNotes {
    <#
    .SYNOPSIS
        Full Sticky Notes uninstall: choco uninstall, purge tracking.
    #>
    param(
        $StickyConfig,
        $LogMessages
    )

    $packageName = $StickyConfig.chocoPackage

    # 1. Uninstall via Chocolatey
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "Simple Sticky Notes") -Level "info"
    $isUninstalled = Uninstall-ChocoPackage -PackageName $packageName
    if ($isUninstalled) {
        Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "Simple Sticky Notes") -Level "success"
    } else {
        Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "Simple Sticky Notes") -Level "error"
    }

    # 2. Remove tracking records
    Remove-InstalledRecord -Name "sticky-notes"
    Remove-ResolvedData -ScriptFolder "34-install-sticky-notes"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
