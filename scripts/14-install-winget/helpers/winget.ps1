<#
.SYNOPSIS
    Winget verification and install helpers for script 14.
#>

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-Winget {
    param(
        [PSCustomObject]$Config,
        $LogMessages
    )

    $isDisabled = -not $Config.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.wingetDisabled -Level "info"
        return $true
    }

    Write-Log $LogMessages.messages.wingetChecking -Level "info"
    $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue

    if ($wingetCmd) {
        $version = & winget.exe --version 2>&1
        $versionStr = "$version".Trim()

        # Check .installed/ tracking
        $isAlreadyTracked = Test-AlreadyInstalled -Name "winget" -CurrentVersion $versionStr
        if ($isAlreadyTracked) {
            Write-Log ($LogMessages.messages.wingetFound -replace '\{version\}', $version) -Level "info"
            return $true
        }

        Write-Log ($LogMessages.messages.wingetFound -replace '\{version\}', $version) -Level "success"
        Save-InstalledRecord -Name "winget" -Version $versionStr -Method "system"

        Save-ResolvedData -ScriptFolder "14-install-winget" -Data @{
            winget = @{
                version    = $versionStr
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    }

    $isInstallDisabled = -not $Config.installIfMissing
    if ($isInstallDisabled) {
        Write-Log $LogMessages.messages.wingetNotFoundSkip -Level "warn"
        return $false
    }

    Write-Log $LogMessages.messages.wingetNotFound -Level "info"

    try {
        Write-Log ($LogMessages.messages.wingetDownloading -replace '\{url\}', $Config.msStoreUrl) -Level "info"
        $installerPath = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller.msixbundle"

        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Config.msStoreUrl -OutFile $installerPath -UseBasicParsing

        Write-Log $LogMessages.messages.wingetInstalling -Level "info"
        Add-AppxPackage -Path $installerPath -ErrorAction Stop

        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

        $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            $version = & winget.exe --version 2>&1
            Write-Log ($LogMessages.messages.wingetInstallSuccess -replace '\{version\}', $version) -Level "success"
            Save-InstalledRecord -Name "winget" -Version "$version".Trim() -Method "msix"

            Save-ResolvedData -ScriptFolder "14-install-winget" -Data @{
                winget = @{
                    version    = "$version".Trim()
                    resolvedAt = (Get-Date -Format "o")
                    resolvedBy = $env:USERNAME
                }
            }

            return $true
        } else {
            Write-Log $LogMessages.messages.wingetNotInPath -Level "error"
            Write-Log $LogMessages.messages.wingetManualStore -Level "info"
            return $false
        }
    } catch {
        Write-Log ($LogMessages.messages.wingetInstallFailed -replace '\{error\}', $_) -Level "error"
        Write-Log $LogMessages.messages.wingetManualHint -Level "info"
        Save-InstalledError -Name "winget" -ErrorMessage "$_" -Method "msix"
        return $false
    } finally {
        if (Test-Path $installerPath -ErrorAction SilentlyContinue) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Uninstall-Winget {
    <#
    .SYNOPSIS
        Winget uninstall: removes tracking records only (Winget is a system component).
    #>
    param(
        $Config,
        $LogMessages
    )

    Write-Log "Winget is a system component -- removing tracking records only" -Level "warn"

    # Remove tracking records
    Remove-InstalledRecord -Name "winget"
    Remove-ResolvedData -ScriptFolder "14-install-winget"

    Write-Log $LogMessages.messages.uninstallComplete -Level "success"
}
