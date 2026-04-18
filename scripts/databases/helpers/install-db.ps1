<#
.SYNOPSIS
    Generic database install helper. Installs a single database using
    Chocolatey (or dotnet tool) and verifies the installation.
#>

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

function Install-Database {
    <#
    .SYNOPSIS
        Installs a single database from config entry.
        Returns $true on success, $false on failure.
    #>
    param(
        [string]$DbKey,
        [PSCustomObject]$DbConfig,
        $LogMessages,
        [string]$InstallPath = ""
    )

    $name = $DbConfig.name

    $isDisabled = -not $DbConfig.enabled
    if ($isDisabled) {
        Write-Log ($LogMessages.messages.dbDisabled -replace '\{name\}', $name) -Level "info"
        return $true
    }

    Write-Log ($LogMessages.messages.checking -replace '\{name\}', $name) -Level "info"

    $cmd = Get-Command $DbConfig.verifyCommand -ErrorAction SilentlyContinue
    if ($cmd) {
        $version = ""
        try {
            $version = & $DbConfig.verifyCommand $DbConfig.versionFlag 2>&1 | Select-Object -First 1
        } catch { $version = "(version check failed)" }

        $versionStr = "$version".Trim()

        # Check .installed/ tracking -- skip if version matches
        $isAlreadyTracked = Test-AlreadyInstalled -Name $DbKey -CurrentVersion $versionStr
        if ($isAlreadyTracked) {
            Write-Log ($LogMessages.messages.found -replace '\{name\}', $name -replace '\{version\}', $version) -Level "info"
            return $true
        }

        Write-Log ($LogMessages.messages.found -replace '\{name\}', $name -replace '\{version\}', $version) -Level "success"

        $method = if ($DbConfig.installMethod -eq "dotnet-tool") { "dotnet-tool" } else { "chocolatey" }
        Save-InstalledRecord -Name $DbKey -Version $versionStr -Method $method

        Save-ResolvedData -ScriptFolder "databases" -Data @{
            $DbKey = @{
                version    = $versionStr
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    }

    Write-Log ($LogMessages.messages.notFound -replace '\{name\}', $name) -Level "info"
    Write-Log ($LogMessages.messages.installing -replace '\{name\}', $name) -Level "info"

    # Build install args
    $chocoArgs = @()

    # Install via appropriate method
    $isInstalled = $false
    $isDotnetTool = $DbConfig.installMethod -eq "dotnet-tool"
    if ($isDotnetTool) {
        try {
            $dotnetCmd = Get-Command "dotnet" -ErrorAction SilentlyContinue
            $hasDotnet = [bool]$dotnetCmd
            if ($hasDotnet) {
                & dotnet tool install -g $DbConfig.dotnetPackage 2>&1 | Out-Null
                $isInstalled = $true
            } else {
                Write-Log ($LogMessages.messages.installFailed -replace '\{name\}', $name -replace '\{error\}', "dotnet CLI not found") -Level "error"
                return $false
            }
        } catch {
            Write-Log ($LogMessages.messages.installFailed -replace '\{name\}', $name -replace '\{error\}', $_.Exception.Message) -Level "error"
            Save-InstalledError -Name $DbKey -ErrorMessage $_.Exception.Message -Method "dotnet-tool"
            return $false
        }
    } else {
        $isInstalled = Install-ChocoPackage -PackageName $DbConfig.chocoPackage -ExtraArgs $chocoArgs
    }

    $hasInstallFailed = -not $isInstalled
    if ($hasInstallFailed) {
        Write-Log ($LogMessages.messages.installFailed -replace '\{name\}', $name -replace '\{error\}', "Install returned failure") -Level "error"
        return $false
    }

    # Refresh PATH
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    $cmd = Get-Command $DbConfig.verifyCommand -ErrorAction SilentlyContinue
    if ($cmd) {
        $version = ""
        try {
            $version = & $DbConfig.verifyCommand $DbConfig.versionFlag 2>&1 | Select-Object -First 1
        } catch { $version = "(version check failed)" }

        $versionStr = "$version".Trim()
        Write-Log ($LogMessages.messages.installSuccess -replace '\{name\}', $name -replace '\{version\}', $version) -Level "success"

        $method = if ($isDotnetTool) { "dotnet-tool" } else { "chocolatey" }
        Save-InstalledRecord -Name $DbKey -Version $versionStr -Method $method

        Save-ResolvedData -ScriptFolder "databases" -Data @{
            $DbKey = @{
                version    = $versionStr
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    } else {
        Write-Log ($LogMessages.messages.notInPath -replace '\{name\}', $name) -Level "warn"
        return $false
    }
}
