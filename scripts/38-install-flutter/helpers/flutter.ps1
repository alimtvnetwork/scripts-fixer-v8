# --------------------------------------------------------------------------
#  Flutter helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-Flutter {
    param(
        $Config,
        $LogMessages
    )

    $packageName = $Config.flutter.chocoPackageName

    $existing = Get-Command flutter -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = try { & flutter --version --machine 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue } catch { $null }
        $versionStr = if ($currentVersion) { $currentVersion.frameworkVersion } else { try { & flutter --version 2>$null | Select-Object -First 1 } catch { $null } }
        $hasVersion = -not [string]::IsNullOrWhiteSpace($versionStr)

        # Check .installed/ tracking -- skip if version matches
        if ($hasVersion) {
            $isAlreadyTracked = Test-AlreadyInstalled -Name "flutter" -CurrentVersion $versionStr
            if ($isAlreadyTracked) {
                Write-Log ($LogMessages.messages.flutterAlreadyInstalled -replace '\{version\}', $versionStr) -Level "info"
                return
            }
        }

        Write-Log ($LogMessages.messages.flutterAlreadyInstalled -replace '\{version\}', $versionStr) -Level "info"

        if ($Config.flutter.alwaysUpgradeToLatest) {
            try {
                Upgrade-ChocoPackage -PackageName $packageName
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $newVersionData = try { & flutter --version --machine 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue } catch { $null }
                $newVersion = if ($newVersionData) { $newVersionData.frameworkVersion } else { "(version pending)" }
                Write-Log ($LogMessages.messages.flutterUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
                Save-InstalledRecord -Name "flutter" -Version $newVersion
            } catch {
                Write-Log "Flutter upgrade failed: $_" -Level "error"
                Save-InstalledError -Name "flutter" -ErrorMessage "$_"
            }
        }
    }
    else {
        Write-Log $LogMessages.messages.flutterNotFound -Level "info"
        try {
            Install-ChocoPackage -PackageName $packageName

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            $installedData = & flutter --version --machine 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
            $installedVersion = if ($installedData) { $installedData.frameworkVersion } else { "installed" }
            Write-Log ($LogMessages.messages.flutterInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
            Save-InstalledRecord -Name "flutter" -Version $installedVersion
        } catch {
            Write-Log "Flutter install failed: $_" -Level "error"
            Save-InstalledError -Name "flutter" -ErrorMessage "$_"
        }
    }

    # Log Dart version (bundled with Flutter)
    $dartVersion = & dart --version 2>$null
    if ($dartVersion) {
        Write-Log ($LogMessages.messages.dartVersion -replace '\{version\}', $dartVersion) -Level "info"
    }
}


function Install-AndroidStudio {
    param(
        $Config,
        $LogMessages
    )

    $isDisabled = -not $Config.androidStudio.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.androidStudioSkipped -Level "info"
        return
    }

    $packageName = $Config.androidStudio.chocoPackageName

    # Check if Android Studio is already installed (check common paths)
    $studioPath = "${env:ProgramFiles}\Android\Android Studio"
    $studioPathX86 = "${env:ProgramFiles(x86)}\Android\Android Studio"
    $isInstalled = (Test-Path $studioPath) -or (Test-Path $studioPathX86)

    if ($isInstalled) {
        $isAlreadyTracked = Test-AlreadyInstalled -Name "android-studio"
        if ($isAlreadyTracked) {
            Write-Log $LogMessages.messages.androidStudioAlreadyInstalled -Level "info"
            return
        }

        Write-Log $LogMessages.messages.androidStudioAlreadyInstalled -Level "info"
        Save-InstalledRecord -Name "android-studio" -Version "detected"
    }
    else {
        Write-Log $LogMessages.messages.androidStudioNotFound -Level "info"
        try {
            Install-ChocoPackage -PackageName $packageName
            Write-Log $LogMessages.messages.androidStudioInstallSuccess -Level "success"
            Save-InstalledRecord -Name "android-studio" -Version "installed"
        } catch {
            Write-Log "Android Studio install failed: $_" -Level "error"
            Save-InstalledError -Name "android-studio" -ErrorMessage "$_"
        }
    }
}


function Install-Chrome {
    param(
        $Config,
        $LogMessages
    )

    $isDisabled = -not $Config.chrome.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.chromeSkipped -Level "info"
        return
    }

    $packageName = $Config.chrome.chocoPackageName

    $existing = Get-Command chrome -ErrorAction SilentlyContinue
    $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    $chromePathX86 = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    $isInstalled = $existing -or (Test-Path $chromePath) -or (Test-Path $chromePathX86)

    if ($isInstalled) {
        $isAlreadyTracked = Test-AlreadyInstalled -Name "chrome"
        if ($isAlreadyTracked) {
            Write-Log $LogMessages.messages.chromeAlreadyInstalled -Level "info"
            return
        }

        Write-Log $LogMessages.messages.chromeAlreadyInstalled -Level "info"
        Save-InstalledRecord -Name "chrome" -Version "detected"
    }
    else {
        Write-Log $LogMessages.messages.chromeNotFound -Level "info"
        try {
            Install-ChocoPackage -PackageName $packageName
            Write-Log $LogMessages.messages.chromeInstallSuccess -Level "success"
            Save-InstalledRecord -Name "chrome" -Version "installed"
        } catch {
            Write-Log "Chrome install failed: $_" -Level "error"
            Save-InstalledError -Name "chrome" -ErrorMessage "$_"
        }
    }
}


function Install-FlutterVscodeExtensions {
    param(
        $Config,
        $LogMessages
    )

    $isDisabled = -not $Config.vscodeExtensions.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.vscodeExtensionsSkipped -Level "info"
        return
    }

    Write-Log $LogMessages.messages.installingVscodeExtensions -Level "info"

    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    $hasNoCode = -not $codeCmd
    if ($hasNoCode) {
        Write-Log "VS Code not found in PATH -- skipping extension install." -Level "warn"
        return
    }

    # Get currently installed extensions
    $installedExtensions = & code --list-extensions 2>$null

    foreach ($ext in $Config.vscodeExtensions.extensions) {
        $isAlreadyInstalled = $installedExtensions -contains $ext
        if ($isAlreadyInstalled) {
            Write-Log ($LogMessages.messages.vscodeExtensionAlready -replace '\{extension\}', $ext) -Level "info"
        }
        else {
            & code --install-extension $ext --force 2>$null
            Write-Log ($LogMessages.messages.vscodeExtensionInstalled -replace '\{extension\}', $ext) -Level "success"
        }
    }
}


function Invoke-FlutterDoctor {
    param(
        $Config,
        $LogMessages
    )

    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    $hasNoFlutter = -not $flutterCmd
    if ($hasNoFlutter) {
        Write-Log "Flutter not found in PATH -- skipping flutter doctor." -Level "warn"
        return
    }

    # Accept Android licenses if configured
    if ($Config.postInstall.acceptAndroidLicenses) {
        Write-Log $LogMessages.messages.acceptingLicenses -Level "info"
        $null = echo "y" | flutter doctor --android-licenses 2>$null
        Write-Log $LogMessages.messages.licensesAccepted -Level "info"
    }

    # Run flutter doctor
    Write-Log $LogMessages.messages.runningFlutterDoctor -Level "info"
    & flutter doctor 2>$null
    Write-Log $LogMessages.messages.flutterDoctorComplete -Level "success"
}

function Uninstall-Flutter {
    <#
    .SYNOPSIS
        Full Flutter uninstall: choco uninstall Flutter, Android Studio, Chrome, purge tracking.
    #>
    param(
        $Config,
        $LogMessages
    )

    # 1. Uninstall Flutter SDK
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "Flutter SDK") -Level "info"
    $isUninstalled = Uninstall-ChocoPackage -PackageName $Config.flutter.chocoPackageName
    if ($isUninstalled) {
        Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "Flutter SDK") -Level "success"
    } else {
        Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "Flutter SDK") -Level "error"
    }

    # 2. Uninstall Android Studio
    $hasAndroid = $Config.androidStudio.enabled
    if ($hasAndroid) {
        Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "Android Studio") -Level "info"
        Uninstall-ChocoPackage -PackageName $Config.androidStudio.chocoPackageName
    }

    # 3. Uninstall Chrome (optional -- skip since it may be user-installed)
    # Write-Log "Skipping Chrome uninstall (may be user-installed)" -Level "info"

    # 4. Remove tracking records
    Remove-InstalledRecord -Name "flutter"
    Remove-InstalledRecord -Name "androidstudio"
    Remove-ResolvedData -ScriptFolder "38-install-flutter"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
