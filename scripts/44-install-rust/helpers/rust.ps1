# --------------------------------------------------------------------------
#  Rust toolchain helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-Rust {
    param(
        $Config,
        $LogMessages
    )

    $existing = Get-Command rustc -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = try { & rustc --version 2>$null } catch { $null }
        $hasVersion = -not [string]::IsNullOrWhiteSpace($currentVersion)

        # Check .installed/ tracking
        if ($hasVersion) {
            $isAlreadyTracked = Test-AlreadyInstalled -Name "rust" -CurrentVersion $currentVersion
            if ($isAlreadyTracked) {
                Write-Log ($LogMessages.messages.rustAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"
                return
            }
        }

        Write-Log ($LogMessages.messages.rustAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($Config.alwaysUpgradeToLatest) {
            try {
                & rustup update $Config.defaultToolchain 2>&1 | Out-Null
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $newVersion = try { & rustc --version 2>$null } catch { $null }
                $isVersionEmpty = [string]::IsNullOrWhiteSpace($newVersion)
                if ($isVersionEmpty) { $newVersion = "(version pending)" }
                Write-Log ($LogMessages.messages.rustUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
                Save-InstalledRecord -Name "rust" -Version "$newVersion".Trim()
            } catch {
                Write-Log "Rust upgrade failed: $_" -Level "error"
                Save-InstalledError -Name "rust" -ErrorMessage "$_"
            }
        }
    }
    else {
        Write-Log $LogMessages.messages.rustNotFound -Level "info"
        try {
            # Download rustup-init.exe
            $rustupExe = Join-Path $env:TEMP "rustup-init.exe"
            Write-Log $LogMessages.messages.downloadingRustup -Level "info"
            Invoke-DownloadWithRetry -Url $Config.rustupUrl -OutFile $rustupExe

            # Run rustup-init with default toolchain, no prompts
            Write-Log ($LogMessages.messages.runningRustupInit -replace '\{toolchain\}', $Config.defaultToolchain) -Level "info"
            & $rustupExe -y --default-toolchain $Config.defaultToolchain 2>&1 | Out-Null

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            $installedVersion = & rustc --version 2>$null
            Write-Log ($LogMessages.messages.rustInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
            Save-InstalledRecord -Name "rust" -Version $installedVersion

            # Cleanup
            $isRustupTempPresent = Test-Path $rustupExe
            if ($isRustupTempPresent) { Remove-Item $rustupExe -Force }
        } catch {
            Write-Log "Rust install failed: $_" -Level "error"
            Save-InstalledError -Name "rust" -ErrorMessage "$_"
        }
    }
}

function Install-RustComponents {
    param(
        $Config,
        $LogMessages
    )

    $hasRustup = Get-Command rustup -ErrorAction SilentlyContinue
    $isRustupMissing = -not $hasRustup
    if ($isRustupMissing) {
        Write-Log "rustup not found -- cannot install components" -Level "warn"
        return
    }

    # Install configured components
    $installedComponents = & rustup component list --installed 2>$null
    foreach ($comp in @("clippy", "rustfmt", "rust-analyzer")) {
        $isEnabled = $Config.components.$comp
        if (-not $isEnabled) { continue }

        $isAlreadyInstalled = $installedComponents -match $comp
        if ($isAlreadyInstalled) {
            Write-Log ($LogMessages.messages.componentAlreadyInstalled -replace '\{component\}', $comp) -Level "info"
        } else {
            Write-Log ($LogMessages.messages.componentInstalling -replace '\{component\}', $comp) -Level "info"
            try {
                & rustup component add $comp 2>&1 | Out-Null
                Write-Log ($LogMessages.messages.componentInstallSuccess -replace '\{component\}', $comp) -Level "success"
            } catch {
                Write-Log "Failed to install component $comp`: $_" -Level "error"
            }
        }
    }

    # Add WASM target if configured
    $isWasmEnabled = $Config.targets.addWasm
    if ($isWasmEnabled) {
        $installedTargets = & rustup target list --installed 2>$null
        $wasmTarget = $Config.targets.wasmTarget
        $isWasmPresent = $installedTargets -match $wasmTarget
        if ($isWasmPresent) {
            Write-Log ($LogMessages.messages.targetAlreadyAdded -replace '\{target\}', $wasmTarget) -Level "info"
        } else {
            Write-Log ($LogMessages.messages.targetAdding -replace '\{target\}', $wasmTarget) -Level "info"
            & rustup target add $wasmTarget 2>&1 | Out-Null
        }
    }

    # Install cargo packages if configured
    $isCargoPackagesEnabled = $Config.cargoPackages.enabled
    if ($isCargoPackagesEnabled) {
        foreach ($pkg in $Config.cargoPackages.packages) {
            Write-Log ($LogMessages.messages.cargoPackageInstalling -replace '\{package\}', $pkg) -Level "info"
            try {
                & cargo install $pkg 2>&1 | Out-Null
                Write-Log ($LogMessages.messages.cargoPackageSuccess -replace '\{package\}', $pkg) -Level "success"
            } catch {
                Write-Log "Failed to install cargo package $pkg`: $_" -Level "error"
            }
        }
    }
}

function Update-RustPath {
    param(
        $Config,
        $LogMessages
    )

    $isPathUpdateDisabled = -not $Config.path.updateUserPath
    if ($isPathUpdateDisabled) { return }

    $cargoHome = $Config.path.cargoHome
    $hasCustomCargoHome = -not [string]::IsNullOrWhiteSpace($cargoHome)
    if (-not $hasCustomCargoHome) {
        $cargoHome = Join-Path $env:USERPROFILE ".cargo"
    }
    $cargoBin = Join-Path $cargoHome "bin"

    $isAlreadyInPath = Test-InPath -Directory $cargoBin
    if ($isAlreadyInPath) {
        Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $cargoBin) -Level "info"
    } else {
        Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $cargoBin) -Level "info"
        Add-ToUserPath -Directory $cargoBin
    }
}

function Uninstall-Rust {
    param(
        $Config,
        $LogMessages
    )

    Write-Log $LogMessages.messages.uninstalling -Level "info"

    $hasRustup = Get-Command rustup -ErrorAction SilentlyContinue
    $isRustupMissing = -not $hasRustup
    if ($isRustupMissing) {
        Write-Log "rustup not found -- nothing to uninstall" -Level "warn"
        return
    }

    try {
        & rustup self uninstall -y 2>&1 | Out-Null
        Write-Log $LogMessages.messages.uninstallSuccess -Level "success"
    } catch {
        Write-Log ($LogMessages.messages.uninstallFailed) -Level "error"
    }

    Remove-InstalledRecord -Name "rust"
    Remove-ResolvedData -ScriptFolder "44-install-rust"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
