# --------------------------------------------------------------------------
#  Helper: Install Notepad++ via Chocolatey and sync settings
#  Supports 3 modes: install+settings (default), settings-only, install-only
# --------------------------------------------------------------------------

function Install-NotepadPP {
    param(
        [Parameter(Mandatory)] $NppConfig,
        [Parameter(Mandatory)] $LogMessages,
        [ValidateSet("install+settings", "settings-only", "install-only")]
        [string]$Mode = "install+settings"
    )

    $msgs = $LogMessages.messages

    # -- Mode announcement ---------------------------------------------
    $modeLabel = switch ($Mode) {
        "install+settings" { "NPP + Settings (install Notepad++ and sync settings)" }
        "settings-only"    { "NPP Settings (sync settings only)" }
        "install-only"     { "Install NPP (install Notepad++ only)" }
    }
    Write-Log "Mode: $modeLabel" -Level "info"
    Write-Host ""

    # -- Settings-only mode: skip install, go straight to sync ---------
    if ($Mode -eq "settings-only") {
        Write-Log "Skipping Notepad++ installation (settings-only mode)" -Level "info"
        $syncResult = Sync-NotepadPPSettings -LogMessages $LogMessages
        return $syncResult
    }

    # -- Check if already installed ------------------------------------
    $nppPath = Get-Command "notepad++" -ErrorAction SilentlyContinue
    if (-not $nppPath) {
        $commonPaths = @(
            "$env:ProgramFiles\Notepad++\notepad++.exe",
            "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
        )
        foreach ($p in $commonPaths) {
            if (Test-Path $p) {
                $nppPath = Get-Item $p
                break
            }
        }
    }

    if ($nppPath) {
        $version = "unknown"
        try {
            $exePath = if ($nppPath -is [System.Management.Automation.ApplicationInfo]) { $nppPath.Source } else { $nppPath.FullName }
            $version = (Get-Item $exePath).VersionInfo.ProductVersion
        } catch { }

        $isAlreadyInstalled = Test-AlreadyInstalled -Name "notepadpp" -CurrentVersion $version
        if ($isAlreadyInstalled) {
            Write-Log ($msgs.alreadyInstalled -replace '\{version\}', $version) -Level "success"
            if ($Mode -eq "install+settings") {
                Sync-NotepadPPSettings -LogMessages $LogMessages
            }
            return $true
        }
    }

    # -- Install via Chocolatey ----------------------------------------
    Write-Log $msgs.notFound -Level "info"
    Write-Host ""
    Write-Log $msgs.installing -Level "info"

    try {
        choco install $NppConfig.chocoPackage -y --no-progress | Out-Null
    } catch {
        Write-Log ($msgs.installFailed -replace '\{error\}', $_) -Level "error"
        Save-InstalledError -Name "notepadpp" -ErrorMessage "$_"
        return $false
    }

    # -- Verify installation -------------------------------------------
    $verifyPaths = @(
        "$env:ProgramFiles\Notepad++\notepad++.exe",
        "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
    )
    $installedPath = $null
    foreach ($p in $verifyPaths) {
        if (Test-Path $p) {
            $installedPath = $p
            break
        }
    }

    if (-not $installedPath) {
        $checkedPaths = $verifyPaths -join ", "
        Write-FileError -FilePath $checkedPaths -Operation "resolve" -Reason "notepad++.exe not found after Chocolatey install -- checked: $checkedPaths" -Module "Install-NotepadPP"
        Write-Log ($msgs.installFailed -replace '\{error\}', "notepad++.exe not found after install") -Level "error"
        return $false
    }

    $version = (Get-Item $installedPath).VersionInfo.ProductVersion
    Write-Log ($msgs.installSuccess) -Level "success"
    Write-Log ("Install target: $installedPath") -Level "success"
    Write-Host ""
    Save-InstalledRecord -Name "notepadpp" -Version $version -Method "chocolatey"

    # -- Sync settings (only in install+settings mode) -----------------
    if ($Mode -eq "install+settings") {
        Sync-NotepadPPSettings -LogMessages $LogMessages
    } else {
        Write-Log "Settings sync skipped (install-only mode)" -Level "info"
    }

    return $true
}

function Sync-NotepadPPSettings {
    param(
        [Parameter(Mandatory)] $LogMessages
    )

    $msgs = $LogMessages.messages
    $scriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.ScriptName)
    $settingsSource = Join-Path $scriptDir "settings"
    $zipFile = Join-Path $settingsSource "notepadpp-settings.zip"

    # -- Target: %APPDATA%\Notepad++ -----------------------------------
    $appDataDir = Join-Path $env:APPDATA "Notepad++"
    Write-Log "Settings target: $appDataDir" -Level "info"

    # -- Check for zip -------------------------------------------------
    if (Test-Path $zipFile) {
        Write-Log $msgs.syncingSettings -Level "info"

        if (-not (Test-Path $appDataDir)) {
            New-Item -Path $appDataDir -ItemType Directory -Force | Out-Null
        }

        try {
            Expand-Archive -Path $zipFile -DestinationPath $appDataDir -Force
            Write-Log ($msgs.settingsSynced -replace '\{path\}', $appDataDir) -Level "success"
            return $true
        } catch {
            Write-FileError -FilePath $zipFile -Operation "extract" -Reason "Failed to extract settings zip to '$appDataDir': $_" -Module "Sync-NotepadPPSettings"
            Write-Log "Failed to extract settings zip: $_" -Level "error"
            return $false
        }
    }

    # -- Fallback: loose files in settings/ ----------------------------
    if (-not (Test-Path $settingsSource)) {
        Write-FileError -FilePath $settingsSource -Operation "read" -Reason "Settings source directory does not exist" -Module "Sync-NotepadPPSettings"
        Write-Log $msgs.settingsSkipped -Level "info"
        return $false
    }

    $settingsFiles = Get-ChildItem -Path $settingsSource -File -Exclude "*.zip" -ErrorAction SilentlyContinue
    if ($settingsFiles.Count -eq 0) {
        Write-FileError -FilePath $settingsSource -Operation "read" -Reason "No settings files found in source directory (excluding .zip)" -Module "Sync-NotepadPPSettings"
        Write-Log $msgs.settingsSkipped -Level "info"
        return $false
    }

    if (-not (Test-Path $appDataDir)) {
        New-Item -Path $appDataDir -ItemType Directory -Force | Out-Null
    }

    Write-Log $msgs.syncingSettings -Level "info"

    foreach ($file in $settingsFiles) {
        $dest = Join-Path $appDataDir $file.Name
        Copy-Item -Path $file.FullName -Destination $dest -Force
    }

    Write-Log ($msgs.settingsSynced -replace '\{path\}', $appDataDir) -Level "success"
    return $true
}

function Export-NotepadPPSettings {
    <#
    .SYNOPSIS
        Exports Notepad++ settings FROM the machine back INTO the repo's
        settings/01 - notepad++/ folder for backup/version control.
    #>
    param(
        [Parameter(Mandatory)] $LogMessages
    )

    $msgs = $LogMessages.messages

    # Source: %APPDATA%\Notepad++\
    $sourceDir = Join-Path $env:APPDATA "Notepad++"

    # Target: repo/settings/01 - notepad++/
    $repoRoot  = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $targetDir = Join-Path $repoRoot "settings\01 - notepad++"

    Write-Log ($msgs.exportStarting -replace '\{source\}', $sourceDir) -Level "info"

    # -- Validate source exists ----------------------------------------
    $isSourceMissing = -not (Test-Path $sourceDir)
    if ($isSourceMissing) {
        Write-FileError -FilePath $sourceDir -Operation "read" -Reason "Notepad++ AppData directory does not exist. Is Notepad++ installed and has been launched at least once?" -Module "Export-NotepadPPSettings"
        Write-Log $msgs.exportNoSource -Level "error"
        return $false
    }

    # -- Ensure target directory exists --------------------------------
    $isTargetMissing = -not (Test-Path $targetDir)
    if ($isTargetMissing) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
        Write-Log "Created settings directory: $targetDir" -Level "info"
    }

    $copiedCount = 0

    # -- Export config files (.xml, .json, .ini) ------------------------
    $configExts = @("*.xml", "*.json", "*.ini", "*.txt")
    foreach ($ext in $configExts) {
        $files = Get-ChildItem -Path $sourceDir -File -Filter $ext -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $isReadme = $file.Name -eq "readme.txt"
            if ($isReadme) { continue }

            $fileSizeKB = [math]::Round($file.Length / 1024, 1)
            $isTooBig = $fileSizeKB -gt 512
            if ($isTooBig) {
                Write-Log "Skipped: $($file.Name) ($fileSizeKB KB -- too large, likely cache)" -Level "info"
                continue
            }

            try {
                $dest = Join-Path $targetDir $file.Name
                Copy-Item -Path $file.FullName -Destination $dest -Force
                Write-Log "Exported: $($file.Name) ($fileSizeKB KB)" -Level "success"
                $copiedCount++
            } catch {
                Write-FileError -FilePath $file.FullName -Operation "copy" -Reason "Failed to export $($file.Name): $_" -Module "Export-NotepadPPSettings"
            }
        }
    }

    # -- Export subdirectories (themes, plugins, userDefineLangs) -------
    $sourceDirs = Get-ChildItem -Path $sourceDir -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $sourceDirs) {
        # Skip session and backup folders (runtime data, not config)
        $skipDirs = @("backup", "session", "plugins")
        $isDirSkipped = $skipDirs -contains $dir.Name.ToLower()
        if ($isDirSkipped) {
            Write-Log "Skipped folder: $($dir.Name) (runtime data)" -Level "info"
            continue
        }

        try {
            $dest = Join-Path $targetDir $dir.Name
            Copy-Item -Path $dir.FullName -Destination $dest -Recurse -Force
            $subCount = (Get-ChildItem $dir.FullName -Recurse -File).Count
            Write-Log "Exported folder: $($dir.Name) ($subCount files)" -Level "success"
            $copiedCount++
        } catch {
            Write-FileError -FilePath $dir.FullName -Operation "copy" -Reason "Failed to export folder $($dir.Name): $_" -Module "Export-NotepadPPSettings"
        }
    }

    $hasNoFiles = $copiedCount -eq 0
    if ($hasNoFiles) {
        Write-Log $msgs.exportNoFiles -Level "warn"
        return $false
    }

    $summary = $msgs.exportComplete -replace '\{count\}', $copiedCount -replace '\{path\}', $targetDir
    Write-Log $summary -Level "success"
    return $true
}

function Uninstall-NotepadPP {
    <#
    .SYNOPSIS
        Full Notepad++ uninstall: choco uninstall, purge tracking.
    #>
    param(
        $NppConfig,
        $LogMessages
    )

    $packageName = $NppConfig.chocoPackage

    # 1. Uninstall via Chocolatey
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "Notepad++") -Level "info"
    $isUninstalled = Uninstall-ChocoPackage -PackageName $packageName
    if ($isUninstalled) {
        Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "Notepad++") -Level "success"
    } else {
        Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "Notepad++") -Level "error"
    }

    # 2. Remove tracking records
    Remove-InstalledRecord -Name "notepadpp"
    Remove-ResolvedData -ScriptFolder "33-install-notepadpp"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
