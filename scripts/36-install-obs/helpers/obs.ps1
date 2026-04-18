# --------------------------------------------------------------------------
#  Helper: Install OBS Studio via Chocolatey and sync settings
#  Supports 3 modes: install+settings (default), settings-only, install-only
# --------------------------------------------------------------------------

function Install-OBS {
    param(
        [Parameter(Mandatory)] $ObsConfig,
        [Parameter(Mandatory)] $LogMessages,
        [ValidateSet("install+settings", "settings-only", "install-only")]
        [string]$Mode = "install+settings"
    )

    $msgs = $LogMessages.messages

    # -- Mode announcement ---------------------------------------------
    $modeLabel = switch ($Mode) {
        "install+settings" { "OBS + Settings (install OBS Studio and sync settings)" }
        "settings-only"    { "OBS Settings (sync settings only)" }
        "install-only"     { "Install OBS (install OBS Studio only)" }
    }
    Write-Log "Mode: $modeLabel" -Level "info"
    Write-Host ""

    # -- Settings-only mode: skip install, go straight to sync ---------
    if ($Mode -eq "settings-only") {
        Write-Log "Skipping OBS Studio installation (settings-only mode)" -Level "info"
        $syncResult = Sync-OBSSettings -LogMessages $LogMessages
        return $syncResult
    }

    # -- Check if already installed ------------------------------------
    $obsPath = $null
    $commonPaths = @(
        "$env:ProgramFiles\obs-studio\bin\64bit\obs64.exe",
        "${env:ProgramFiles(x86)}\obs-studio\bin\64bit\obs64.exe"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path $p) {
            $obsPath = Get-Item $p
            break
        }
    }

    # Fallback: check Get-Command
    if (-not $obsPath) {
        $obsCmd = Get-Command "obs64" -ErrorAction SilentlyContinue
        if ($obsCmd) {
            $obsPath = Get-Item $obsCmd.Source
        }
    }

    if ($obsPath) {
        $version = "unknown"
        try {
            $exePath = if ($obsPath -is [System.Management.Automation.ApplicationInfo]) { $obsPath.Source } else { $obsPath.FullName }
            $version = (Get-Item $exePath).VersionInfo.ProductVersion
        } catch { }

        $isAlreadyInstalled = Test-AlreadyInstalled -Name "obs" -CurrentVersion $version
        if ($isAlreadyInstalled) {
            Write-Log ($msgs.alreadyInstalled -replace '\{version\}', $version) -Level "success"
            # Settings always sync (user may want to restore/fix)
            if ($Mode -eq "install+settings") {
                $syncOk = Sync-OBSSettings -LogMessages $LogMessages
                return $syncOk
            }
            return $true
        }
    }

    # -- Install via Chocolatey ----------------------------------------
    Write-Log $msgs.notFound -Level "info"
    Write-Host ""
    Write-Log $msgs.installing -Level "info"

    try {
        choco install $ObsConfig.chocoPackage -y --no-progress | Out-Null
    } catch {
        Write-FileError -FilePath "$env:ProgramFiles\obs-studio\bin\64bit\obs64.exe" -Operation "install" -Reason "$_" -Module "Install-OBS"
        Write-Log ($msgs.installFailed -replace '\{error\}', $_) -Level "error"
        Save-InstalledError -Name "obs" -ErrorMessage "$_"
        return $false
    }

    # -- Verify installation -------------------------------------------
    $verifyPaths = @(
        "$env:ProgramFiles\obs-studio\bin\64bit\obs64.exe",
        "${env:ProgramFiles(x86)}\obs-studio\bin\64bit\obs64.exe"
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
        Write-FileError -FilePath $checkedPaths -Operation "resolve" -Reason "obs64.exe not found after Chocolatey install -- checked: $checkedPaths" -Module "Install-OBS"
        Write-Log ($msgs.installFailed -replace '\{error\}', "obs64.exe not found after install") -Level "error"
        return $false
    }

    $version = (Get-Item $installedPath).VersionInfo.ProductVersion
    Write-Log ($msgs.installSuccess) -Level "success"
    Write-Log ("Install target: $installedPath") -Level "success"
    Write-Host ""
    Save-InstalledRecord -Name "obs" -Version $version -Method "chocolatey"

    # -- Sync settings (only in install+settings mode) -----------------
    if ($Mode -eq "install+settings") {
        $syncOk = Sync-OBSSettings -LogMessages $LogMessages
        return $syncOk
    } else {
        Write-Log "Settings sync skipped (install-only mode)" -Level "info"
    }

    return $true
}

function Sync-OBSSettings {
    param(
        [Parameter(Mandatory)] $LogMessages
    )

    $msgs = $LogMessages.messages
    # $PSScriptRoot = helpers/ -> parent = 36-install-obs/ -> parent = scripts/ -> parent = repo root
    $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $settingsSource = Join-Path $repoRoot "settings\02 - obs-settings"

    # -- Target dirs: %APPDATA%\obs-studio\basic\{scenes,profiles} -----
    $appDataDir = Join-Path $env:APPDATA "obs-studio"
    $scenesDir  = Join-Path $appDataDir "basic\scenes"
    $profilesDir = Join-Path $appDataDir "basic\profiles"
    Write-Log "Settings target: $appDataDir" -Level "info"

    # -- Find the zip file (first .zip in settings source) -------------
    if (-not (Test-Path $settingsSource)) {
        Write-FileError -FilePath $settingsSource -Operation "read" -Reason "OBS settings source directory does not exist" -Module "Sync-OBSSettings"
        Write-Log $msgs.settingsSkipped -Level "info"
        return $false
    }

    $zipFile = Get-ChildItem -Path $settingsSource -Filter "*.zip" -File | Select-Object -First 1
    if (-not $zipFile) {
        Write-FileError -FilePath $settingsSource -Operation "read" -Reason "No .zip file found in OBS settings source directory" -Module "Sync-OBSSettings"
        Write-Log $msgs.settingsSkipped -Level "info"
        return $false
    }

    Write-Log ($msgs.syncingSettings -replace '\{zip\}', $zipFile.Name) -Level "info"

    # -- Extract to temp ------------------------------------------------
    $tempDir = Join-Path $env:TEMP "obs-settings-extract-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    try {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        Expand-Archive -Path $zipFile.FullName -DestinationPath $tempDir -Force
    } catch {
        Write-FileError -FilePath $zipFile.FullName -Operation "extract" -Reason "Failed to extract OBS settings zip: $_" -Module "Sync-OBSSettings"
        Write-Log "Failed to extract settings zip: $_" -Level "error"
        return $false
    }

    # -- Ensure target directories exist --------------------------------
    foreach ($dir in @($scenesDir, $profilesDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }

    # -- Copy JSON scene collections to basic\scenes\ ------------------
    $jsonFiles = Get-ChildItem -Path $tempDir -Filter "*.json" -File
    $sceneCount = 0
    foreach ($file in $jsonFiles) {
        $dest = Join-Path $scenesDir $file.Name
        Copy-Item -Path $file.FullName -Destination $dest -Force
        $sceneCount++
    }
    Write-Log "Copied $sceneCount scene collection(s) to $scenesDir" -Level "success"

    # -- Copy profile folders to basic\profiles\ -----------------------
    $profileFolders = Get-ChildItem -Path $tempDir -Directory
    $profileCount = 0
    foreach ($folder in $profileFolders) {
        $dest = Join-Path $profilesDir $folder.Name
        Copy-Item -Path $folder.FullName -Destination $dest -Recurse -Force
        $profileCount++
    }
    if ($profileCount -gt 0) {
        Write-Log "Copied $profileCount profile(s) to $profilesDir" -Level "success"
    }

    # -- Cleanup temp ---------------------------------------------------
    try {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch { }

    Write-Log ($msgs.settingsSynced -replace '\{path\}', $appDataDir) -Level "success"
    return $true
}

function Export-OBSSettings {
    <#
    .SYNOPSIS
        Exports OBS settings FROM the machine back INTO the repo's
        settings/02 - obs-settings/ folder for backup/version control.
    #>
    param(
        [Parameter(Mandatory)] $LogMessages
    )

    $msgs = $LogMessages.messages

    # Source directories
    $appDataDir  = Join-Path $env:APPDATA "obs-studio"
    $scenesDir   = Join-Path $appDataDir "basic\scenes"
    $profilesDir = Join-Path $appDataDir "basic\profiles"

    # Target: repo/settings/02 - obs-settings/
    $repoRoot  = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $targetDir = Join-Path $repoRoot "settings\02 - obs-settings"

    Write-Log ($msgs.exportStarting -replace '\{source\}', $appDataDir) -Level "info"

    # -- Validate source exists ----------------------------------------
    $isSourceMissing = -not (Test-Path $appDataDir)
    if ($isSourceMissing) {
        Write-FileError -FilePath $appDataDir -Operation "read" -Reason "OBS data directory does not exist. Is OBS installed and has been launched at least once?" -Module "Export-OBSSettings"
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

    # -- Export scene collections (.json files) -------------------------
    $hasScenesDir = Test-Path $scenesDir
    if ($hasScenesDir) {
        $sceneFiles = Get-ChildItem -Path $scenesDir -File -Filter "*.json" -ErrorAction SilentlyContinue
        foreach ($file in $sceneFiles) {
            $fileSizeKB = [math]::Round($file.Length / 1024, 1)
            $isTooBig = $fileSizeKB -gt 512
            if ($isTooBig) {
                Write-Log "Skipped: $($file.Name) ($fileSizeKB KB -- too large)" -Level "info"
                continue
            }
            try {
                $dest = Join-Path $targetDir $file.Name
                Copy-Item -Path $file.FullName -Destination $dest -Force
                Write-Log "Exported scene: $($file.Name) ($fileSizeKB KB)" -Level "success"
                $copiedCount++
            } catch {
                Write-FileError -FilePath $file.FullName -Operation "copy" -Reason "Failed to export $($file.Name): $_" -Module "Export-OBSSettings"
            }
        }
    }

    # -- Export profile folders -----------------------------------------
    $hasProfilesDir = Test-Path $profilesDir
    if ($hasProfilesDir) {
        $profileFolders = Get-ChildItem -Path $profilesDir -Directory -ErrorAction SilentlyContinue
        foreach ($folder in $profileFolders) {
            try {
                $dest = Join-Path $targetDir $folder.Name
                Copy-Item -Path $folder.FullName -Destination $dest -Recurse -Force
                $subCount = (Get-ChildItem $folder.FullName -Recurse -File).Count
                Write-Log "Exported profile: $($folder.Name) ($subCount files)" -Level "success"
                $copiedCount++
            } catch {
                Write-FileError -FilePath $folder.FullName -Operation "copy" -Reason "Failed to export profile $($folder.Name): $_" -Module "Export-OBSSettings"
            }
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

function Uninstall-OBS {
    <#
    .SYNOPSIS
        Full OBS Studio uninstall: choco uninstall, purge tracking.
    #>
    param(
        $ObsConfig,
        $LogMessages
    )

    $packageName = $ObsConfig.chocoPackage

    # 1. Uninstall via Chocolatey
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "OBS Studio") -Level "info"
    $isUninstalled = Uninstall-ChocoPackage -PackageName $packageName
    if ($isUninstalled) {
        Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "OBS Studio") -Level "success"
    } else {
        Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "OBS Studio") -Level "error"
    }

    # 2. Remove tracking records
    Remove-InstalledRecord -Name "obs"
    Remove-ResolvedData -ScriptFolder "36-install-obs"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
