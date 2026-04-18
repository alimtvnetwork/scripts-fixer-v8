<#
.SYNOPSIS
    PHP + phpMyAdmin install helpers for script 16.
#>

$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}
$_chocoUtilsPath = Join-Path $_sharedDir "choco-utils.ps1"
if ((Test-Path $_chocoUtilsPath) -and -not (Get-Command Install-ChocoPackage -ErrorAction SilentlyContinue)) {
    . $_chocoUtilsPath
}

function Install-Php {
    param(
        [PSCustomObject]$Config,
        $LogMessages
    )

    $isDisabled = -not $Config.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.phpDisabled -Level "info"
        return $true
    }

    Write-Log $LogMessages.messages.phpChecking -Level "info"
    $phpCmd = Get-Command $Config.verifyCommand -ErrorAction SilentlyContinue

    if ($phpCmd) {
        $version = try { & $Config.verifyCommand $Config.versionFlag 2>&1 | Select-Object -First 1 } catch { $null }
        $versionStr = if ($version) { "$version".Trim() } else { "" }
        $hasVersion = -not [string]::IsNullOrWhiteSpace($versionStr)

        # Check .installed/ tracking
        if ($hasVersion) {
            $isAlreadyTracked = Test-AlreadyInstalled -Name "php" -CurrentVersion $versionStr
            if ($isAlreadyTracked) {
                Write-Log ($LogMessages.messages.phpFound -replace '\{version\}', $version) -Level "info"
                return $true
            }
        }

        Write-Log ($LogMessages.messages.phpFound -replace '\{version\}', $version) -Level "success"
        Save-InstalledRecord -Name "php" -Version $versionStr

        Save-ResolvedData -ScriptFolder "16-install-php" -Data @{
            php = @{
                version    = $versionStr
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    }

    Write-Log $LogMessages.messages.phpNotFound -Level "info"
    Write-Log $LogMessages.messages.phpInstalling -Level "info"

    try {
        $isInstalled = Install-ChocoPackage -PackageName $Config.chocoPackage
        $hasInstallFailed = -not $isInstalled
        if ($hasInstallFailed) {
            Write-FileError -FilePath "php.exe" -Operation "resolve" -Reason "Chocolatey install returned failure for '$($Config.chocoPackage)'" -Module "Install-Php"
            Write-Log ($LogMessages.messages.phpInstallFailed -replace '\{error\}', "Chocolatey install returned failure") -Level "error"
            Save-InstalledError -Name "php" -ErrorMessage "Chocolatey install returned failure"
            return $false
        }
    } catch {
        Write-FileError -FilePath "php.exe" -Operation "install" -Reason "$_" -Module "Install-Php"
        Write-Log ($LogMessages.messages.phpInstallFailed -replace '\{error\}', $_) -Level "error"
        Save-InstalledError -Name "php" -ErrorMessage "$_"
        return $false
    }

    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    $phpCmd = Get-Command $Config.verifyCommand -ErrorAction SilentlyContinue
    if ($phpCmd) {
        $version = & $Config.verifyCommand $Config.versionFlag 2>&1 | Select-Object -First 1
        $versionStr = "$version".Trim()
        Write-Log ($LogMessages.messages.phpInstallSuccess -replace '\{version\}', $version) -Level "success"
        Save-InstalledRecord -Name "php" -Version $versionStr

        Save-ResolvedData -ScriptFolder "16-install-php" -Data @{
            php = @{
                version    = $versionStr
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    } else {
        Write-Log $LogMessages.messages.phpNotInPath -Level "warn"
        return $false
    }
}

# --------------------------------------------------------------------------
#  phpMyAdmin installer
# --------------------------------------------------------------------------
function Install-PhpMyAdmin {
    param(
        [Parameter(Mandatory)] $PmaConfig,
        [Parameter(Mandatory)] $LogMessages
    )

    $msgs = $LogMessages.messages
    $isDisabled = -not $PmaConfig.enabled
    if ($isDisabled) {
        Write-Log "phpMyAdmin is disabled in config -- skipping" -Level "info"
        return $true
    }

    Write-Log $msgs.pmaChecking -Level "info"

    # Check if already installed via Chocolatey
    $chocoList = & choco.exe list --local-only 2>&1 | Select-String -Pattern "^phpmyadmin\s" -ErrorAction SilentlyContinue
    $isAlreadyInstalled = $null -ne $chocoList
    if ($isAlreadyInstalled) {
        Write-Log $msgs.pmaFound -Level "success"
        Save-InstalledRecord -Name "phpmyadmin" -Version "installed" -Method "chocolatey"
        return $true
    }

    # Also check common paths
    $pmaPaths = @(
        "$env:ProgramData\chocolatey\lib\phpmyadmin",
        "C:\tools\phpmyadmin"
    )
    foreach ($p in $pmaPaths) {
        $isPresent = Test-Path $p
        if ($isPresent) {
            Write-Log $msgs.pmaFound -Level "success"
            Save-InstalledRecord -Name "phpmyadmin" -Version "installed" -Method "chocolatey"
            return $true
        }
    }

    Write-Log $msgs.pmaNotFound -Level "info"
    Write-Host ""
    Write-Log $msgs.pmaInstalling -Level "info"

    try {
        $isInstalled = Install-ChocoPackage -PackageName $PmaConfig.chocoPackage
        $hasInstallFailed = -not $isInstalled
        if ($hasInstallFailed) {
            Write-FileError -FilePath "phpmyadmin" -Operation "install" -Reason "Chocolatey install returned failure for '$($PmaConfig.chocoPackage)'" -Module "Install-PhpMyAdmin"
            Write-Log ($msgs.pmaInstallFailed -replace '\{error\}', "Install returned failure") -Level "error"
            Save-InstalledError -Name "phpmyadmin" -ErrorMessage "Chocolatey install returned failure"
            return $false
        }
    } catch {
        Write-FileError -FilePath "phpmyadmin" -Operation "install" -Reason "$_" -Module "Install-PhpMyAdmin"
        Write-Log ($msgs.pmaInstallFailed -replace '\{error\}', $_) -Level "error"
        Save-InstalledError -Name "phpmyadmin" -ErrorMessage "$_"
        return $false
    }

    Write-Log $msgs.pmaInstallSuccess -Level "success"
    Save-InstalledRecord -Name "phpmyadmin" -Version "latest" -Method "chocolatey"
    return $true
}

function Uninstall-Php {
    <#
    .SYNOPSIS
        Full PHP + phpMyAdmin uninstall: choco uninstall both, purge tracking.
    #>
    param(
        $Config,
        $LogMessages
    )

    # 1. Uninstall PHP
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "PHP") -Level "info"
    $isUninstalled = Uninstall-ChocoPackage -PackageName $Config.php.chocoPackage
    if ($isUninstalled) {
        Write-Log ($LogMessages.messages.uninstallSuccess -replace '\{name\}', "PHP") -Level "success"
    } else {
        Write-Log ($LogMessages.messages.uninstallFailed -replace '\{name\}', "PHP") -Level "error"
    }

    # 2. Uninstall phpMyAdmin
    Write-Log ($LogMessages.messages.uninstalling -replace '\{name\}', "phpMyAdmin") -Level "info"
    Uninstall-ChocoPackage -PackageName $Config.phpmyadmin.chocoPackage

    # 3. Remove tracking records
    Remove-InstalledRecord -Name "php"
    Remove-InstalledRecord -Name "phpmyadmin"
    Remove-ResolvedData -ScriptFolder "16-install-php"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
