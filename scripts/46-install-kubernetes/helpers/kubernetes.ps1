# --------------------------------------------------------------------------
#  Kubernetes tools helper functions (kubectl, minikube, Helm, Lens)
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-Kubectl {
    param(
        $Config,
        $LogMessages
    )

    $kcConfig = $Config.kubectl
    $isDisabled = -not $kcConfig.enabled
    if ($isDisabled) { return }

    $packageName = $kcConfig.chocoPackageName

    $existing = Get-Command kubectl -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = try { & kubectl version --client --short 2>$null } catch { $null }
        $hasVersion = -not [string]::IsNullOrWhiteSpace($currentVersion)

        if ($hasVersion) {
            $isAlreadyTracked = Test-AlreadyInstalled -Name "kubectl" -CurrentVersion $currentVersion
            if ($isAlreadyTracked) {
                Write-Log ($LogMessages.messages.kubectlAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"
                return
            }
        }

        Write-Log ($LogMessages.messages.kubectlAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($kcConfig.alwaysUpgradeToLatest) {
            try {
                Upgrade-ChocoPackage -PackageName $packageName
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $newVersion = try { & kubectl version --client --short 2>$null } catch { $null }
                $isVersionEmpty = [string]::IsNullOrWhiteSpace($newVersion)
                if ($isVersionEmpty) { $newVersion = "(version pending)" }
                Write-Log ($LogMessages.messages.kubectlUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
                Save-InstalledRecord -Name "kubectl" -Version "$newVersion".Trim()
            } catch {
                Write-Log "kubectl upgrade failed: $_" -Level "error"
                Save-InstalledError -Name "kubectl" -ErrorMessage "$_"
            }
        }
    }
    else {
        Write-Log $LogMessages.messages.kubectlNotFound -Level "info"
        try {
            Install-ChocoPackage -PackageName $packageName
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $installedVersion = & kubectl version --client --short 2>$null
            Write-Log ($LogMessages.messages.kubectlInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
            Save-InstalledRecord -Name "kubectl" -Version $installedVersion
        } catch {
            Write-Log "kubectl install failed: $_" -Level "error"
            Save-InstalledError -Name "kubectl" -ErrorMessage "$_"
        }
    }
}

function Install-Minikube {
    param(
        $Config,
        $LogMessages
    )

    $mkConfig = $Config.minikube
    $isDisabled = -not $mkConfig.enabled
    if ($isDisabled) { return }

    $packageName = $mkConfig.chocoPackageName

    $existing = Get-Command minikube -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = try { & minikube version --short 2>$null } catch { $null }
        $hasVersion = -not [string]::IsNullOrWhiteSpace($currentVersion)

        if ($hasVersion) {
            $isAlreadyTracked = Test-AlreadyInstalled -Name "minikube" -CurrentVersion $currentVersion
            if ($isAlreadyTracked) {
                Write-Log ($LogMessages.messages.minikubeAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"
                return
            }
        }

        Write-Log ($LogMessages.messages.minikubeAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($mkConfig.alwaysUpgradeToLatest) {
            try {
                Upgrade-ChocoPackage -PackageName $packageName
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $newVersion = try { & minikube version --short 2>$null } catch { $null }
                $isVersionEmpty = [string]::IsNullOrWhiteSpace($newVersion)
                if ($isVersionEmpty) { $newVersion = "(version pending)" }
                Write-Log ($LogMessages.messages.minikubeUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
                Save-InstalledRecord -Name "minikube" -Version "$newVersion".Trim()
            } catch {
                Write-Log "minikube upgrade failed: $_" -Level "error"
                Save-InstalledError -Name "minikube" -ErrorMessage "$_"
            }
        }
    }
    else {
        Write-Log $LogMessages.messages.minikubeNotFound -Level "info"
        try {
            Install-ChocoPackage -PackageName $packageName
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $installedVersion = & minikube version --short 2>$null
            Write-Log ($LogMessages.messages.minikubeInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
            Save-InstalledRecord -Name "minikube" -Version $installedVersion
        } catch {
            Write-Log "minikube install failed: $_" -Level "error"
            Save-InstalledError -Name "minikube" -ErrorMessage "$_"
        }
    }
}

function Install-Helm {
    param(
        $Config,
        $LogMessages
    )

    $helmConfig = $Config.helm
    $isDisabled = -not $helmConfig.enabled
    if ($isDisabled) { return }

    $packageName = $helmConfig.chocoPackageName

    $existing = Get-Command helm -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = try { & helm version --short 2>$null } catch { $null }
        $hasVersion = -not [string]::IsNullOrWhiteSpace($currentVersion)

        if ($hasVersion) {
            $isAlreadyTracked = Test-AlreadyInstalled -Name "helm" -CurrentVersion $currentVersion
            if ($isAlreadyTracked) {
                Write-Log ($LogMessages.messages.helmAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"
                return
            }
        }

        Write-Log ($LogMessages.messages.helmAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($helmConfig.alwaysUpgradeToLatest) {
            try {
                Upgrade-ChocoPackage -PackageName $packageName
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $newVersion = try { & helm version --short 2>$null } catch { $null }
                $isVersionEmpty = [string]::IsNullOrWhiteSpace($newVersion)
                if ($isVersionEmpty) { $newVersion = "(version pending)" }
                Write-Log ($LogMessages.messages.helmUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
                Save-InstalledRecord -Name "helm" -Version "$newVersion".Trim()
            } catch {
                Write-Log "Helm upgrade failed: $_" -Level "error"
                Save-InstalledError -Name "helm" -ErrorMessage "$_"
            }
        }
    }
    else {
        Write-Log $LogMessages.messages.helmNotFound -Level "info"
        try {
            Install-ChocoPackage -PackageName $packageName
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $installedVersion = & helm version --short 2>$null
            Write-Log ($LogMessages.messages.helmInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
            Save-InstalledRecord -Name "helm" -Version $installedVersion
        } catch {
            Write-Log "Helm install failed: $_" -Level "error"
            Save-InstalledError -Name "helm" -ErrorMessage "$_"
        }
    }
}

function Install-Lens {
    param(
        $Config,
        $LogMessages
    )

    $lensConfig = $Config.lens
    $isDisabled = -not $lensConfig.enabled
    if ($isDisabled) { return }

    $packageName = $lensConfig.chocoPackageName

    $existing = Get-Command lens -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log $LogMessages.messages.lensAlreadyInstalled -Level "info"
        return
    }

    Write-Log $LogMessages.messages.lensNotFound -Level "info"
    try {
        Install-ChocoPackage -PackageName $packageName
        Write-Log $LogMessages.messages.lensInstallSuccess -Level "success"
        Save-InstalledRecord -Name "lens" -Version "installed"
    } catch {
        Write-Log "Lens install failed: $_" -Level "error"
        Save-InstalledError -Name "lens" -ErrorMessage "$_"
    }
}

function Update-KubePath {
    param(
        $Config,
        $LogMessages
    )

    $isPathUpdateDisabled = -not $Config.path.updateUserPath
    if ($isPathUpdateDisabled) { return }

    foreach ($tool in @("kubectl", "minikube", "helm")) {
        $exe = Get-Command $tool -ErrorAction SilentlyContinue
        $isMissing = -not $exe
        if ($isMissing) { continue }

        $toolDir = Split-Path -Parent $exe.Source

        $isAlreadyInPath = Test-InPath -Directory $toolDir
        if ($isAlreadyInPath) {
            Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $toolDir) -Level "info"
        } else {
            Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $toolDir) -Level "info"
            Add-ToUserPath -Directory $toolDir
        }
    }
}

function Uninstall-KubeTools {
    param(
        $Config,
        $LogMessages
    )

    # kubectl
    if ($Config.kubectl.enabled) {
        Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "kubectl") -Level "info"
        $isOk = Uninstall-ChocoPackage -PackageName $Config.kubectl.chocoPackageName
        if ($isOk) {
            Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "kubectl") -Level "success"
        } else {
            Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "kubectl") -Level "error"
        }
    }

    # minikube
    if ($Config.minikube.enabled) {
        Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "minikube") -Level "info"
        $isOk = Uninstall-ChocoPackage -PackageName $Config.minikube.chocoPackageName
        if ($isOk) {
            Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "minikube") -Level "success"
        } else {
            Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "minikube") -Level "error"
        }
    }

    # Helm
    if ($Config.helm.enabled) {
        Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "Helm") -Level "info"
        $isOk = Uninstall-ChocoPackage -PackageName $Config.helm.chocoPackageName
        if ($isOk) {
            Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "Helm") -Level "success"
        } else {
            Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "Helm") -Level "error"
        }
    }

    # Lens
    if ($Config.lens.enabled) {
        Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "Lens") -Level "info"
        Uninstall-ChocoPackage -PackageName $Config.lens.chocoPackageName
    }

    Remove-InstalledRecord -Name "kubectl"
    Remove-InstalledRecord -Name "minikube"
    Remove-InstalledRecord -Name "helm"
    Remove-InstalledRecord -Name "lens"
    Remove-ResolvedData -ScriptFolder "46-install-kubernetes"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
