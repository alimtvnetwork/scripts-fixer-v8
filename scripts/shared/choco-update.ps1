<#
.SYNOPSIS
    Enhanced Chocolatey package update helper.

.DESCRIPTION
    Provides Invoke-ChocoUpdate with support for:
    - Outdated check (shows only packages with updates available)
    - Selective update (update specific packages by name)
    - Check-only mode (--check: list outdated, no upgrade)
    - Auto-confirm mode (-y: skip confirmation prompt)
    - Exclude packages (--exclude: upgrade all except listed)
#>

function Get-ChocoOutdated {
    <#
    .SYNOPSIS
        Runs 'choco outdated' and returns structured results.
    .OUTPUTS
        Array of objects with Name, CurrentVersion, AvailableVersion, Pinned properties.
        Returns $null if choco outdated fails.
    #>

    try {
        $rawOutput = & choco.exe outdated --limit-output 2>&1
        $hasExitError = $LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null
    } catch {
        Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
        Write-Host "Failed to run choco outdated: $_"
        return $null
    }

    $packages = @()
    foreach ($line in $rawOutput) {
        $text = $line.ToString().Trim()
        $isEmptyLine = $text.Length -eq 0
        if ($isEmptyLine) { continue }

        # --limit-output format: name|currentVersion|availableVersion|pinned
        $parts = $text -split '\|'
        $isValidLine = $parts.Count -ge 3
        if (-not $isValidLine) { continue }

        $packages += [PSCustomObject]@{
            Name             = $parts[0]
            CurrentVersion   = $parts[1]
            AvailableVersion = $parts[2]
            Pinned           = if ($parts.Count -ge 4) { $parts[3] -eq 'true' } else { $false }
        }
    }

    return $packages
}

function Show-OutdatedTable {
    <#
    .SYNOPSIS
        Displays a formatted table of outdated packages.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Packages
    )

    Write-Host ""
    Write-Host "  Outdated Packages" -ForegroundColor Cyan
    Write-Host "  =================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Package                              Current       Available" -ForegroundColor DarkGray
    Write-Host "    -------------------------------------  -----------  -----------" -ForegroundColor DarkGray

    foreach ($pkg in $Packages) {
        $nameCol    = $pkg.Name.PadRight(41)
        $currentCol = $pkg.CurrentVersion.PadRight(13)
        $availCol   = $pkg.AvailableVersion

        Write-Host "    $nameCol" -NoNewline
        Write-Host "$currentCol" -NoNewline -ForegroundColor Yellow
        Write-Host "$availCol" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline
    Write-Host "$($Packages.Count) package(s) have updates available"
    Write-Host ""
}

function Invoke-ChocoUpdate {
    <#
    .SYNOPSIS
        Enhanced Chocolatey update with outdated check, selective update,
        check-only mode, auto-confirm, and exclude support.

    .PARAMETER Packages
        Optional. Comma-separated package names to update selectively.
        If empty, updates all outdated packages.

    .PARAMETER CheckOnly
        Show outdated packages without upgrading.

    .PARAMETER AutoConfirm
        Skip the [Y/n] confirmation prompt.

    .PARAMETER Exclude
        Comma-separated package names to exclude from upgrade.
    #>
    param(
        [string[]]$Packages = @(),
        [switch]$CheckOnly,
        [switch]$AutoConfirm,
        [string[]]$Exclude = @()
    )

    # -- Ensure Chocolatey is available --------------------------------
    $chocoCmd = Get-Command choco.exe -ErrorAction SilentlyContinue
    $isChocoMissing = -not $chocoCmd
    if ($isChocoMissing) {
        Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
        Write-Host "Chocolatey is not installed. Run .\run.ps1 install choco first."
        return
    }

    Write-Host ""
    Write-Host "  Chocolatey Package Update" -ForegroundColor Cyan
    Write-Host "  =========================" -ForegroundColor DarkGray
    Write-Host ""

    # -- Selective update mode -----------------------------------------
    $hasSelectivePackages = $Packages.Count -gt 0
    if ($hasSelectivePackages) {
        $pkgList = $Packages -join ', '
        Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline
        Write-Host "Selective update: $pkgList"
        Write-Host ""

        if (-not $AutoConfirm) {
            $confirm = Read-Host "  Upgrade $($Packages.Count) package(s)? [Y/n]"
            $isAborted = $confirm.Trim().ToUpper() -eq "N"
            if ($isAborted) {
                Write-Host "  [ SKIP ] Update cancelled by user." -ForegroundColor Yellow
                return
            }
        }

        $successCount = 0
        $failCount    = 0

        foreach ($pkg in $Packages) {
            Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline
            Write-Host "Upgrading: $pkg"

            try {
                & choco.exe upgrade $pkg -y --no-progress 2>&1 | Out-Null
                $hasUpgradeFailed = $LASTEXITCODE -ne 0
                if ($hasUpgradeFailed) {
                    Write-Host "  [ WARN ] " -ForegroundColor Yellow -NoNewline
                    Write-Host "$pkg upgrade returned exit code $LASTEXITCODE"
                    $failCount++
                } else {
                    Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
                    Write-Host "$pkg upgraded"
                    $successCount++
                }
            } catch {
                Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
                Write-Host "Failed to upgrade ${pkg}: $_"
                $failCount++
            }
        }

        Write-Host ""
        Write-Host "  ======================================" -ForegroundColor DarkGray
        Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
        Write-Host "$successCount of $($Packages.Count) upgraded successfully"
        if ($failCount -gt 0) {
            Write-Host "  [ WARN ] " -ForegroundColor Yellow -NoNewline
            Write-Host "$failCount package(s) failed"
        }
        return
    }

    # -- Outdated check ------------------------------------------------
    Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline
    Write-Host "Checking for outdated packages..."

    $outdated = Get-ChocoOutdated
    $isOutdatedNull = $null -eq $outdated
    if ($isOutdatedNull) {
        Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
        Write-Host "Could not retrieve outdated packages"
        return
    }

    # -- Apply exclude filter ------------------------------------------
    $hasExclusions = $Exclude.Count -gt 0
    if ($hasExclusions) {
        $excludeLower = $Exclude | ForEach-Object { $_.Trim().ToLower() }
        $beforeCount = $outdated.Count
        $outdated = @($outdated | Where-Object { $excludeLower -notcontains $_.Name.ToLower() })
        $excludedCount = $beforeCount - $outdated.Count
        if ($excludedCount -gt 0) {
            Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline
            Write-Host "Excluded $excludedCount package(s): $($Exclude -join ', ')"
        }
    }

    # -- No updates available ------------------------------------------
    $hasNoUpdates = $outdated.Count -eq 0
    if ($hasNoUpdates) {
        Write-Host ""
        Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
        Write-Host "All packages are up to date"
        return
    }

    # -- Show outdated table -------------------------------------------
    Show-OutdatedTable -Packages $outdated

    # -- Check-only mode: stop here ------------------------------------
    if ($CheckOnly) {
        Write-Host "  Check-only mode -- no upgrades performed." -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    # -- Confirm -------------------------------------------------------
    if (-not $AutoConfirm) {
        $confirm = Read-Host "  Upgrade $($outdated.Count) package(s)? [Y/n]"
        $isAborted = $confirm.Trim().ToUpper() -eq "N"
        if ($isAborted) {
            Write-Host "  [ SKIP ] Update cancelled by user." -ForegroundColor Yellow
            return
        }
    }

    # -- Run upgrade ---------------------------------------------------
    Write-Host ""
    Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline

    if ($hasExclusions) {
        $excludeArgs = ($Exclude | ForEach-Object { "--except=$_" }) -join ' '
        Write-Host "Running: choco upgrade all -y $excludeArgs"
        Write-Host ""

        # Upgrade individually since choco upgrade all doesn't support --except natively
        $successCount = 0
        $failCount    = 0

        foreach ($pkg in $outdated) {
            Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline
            Write-Host "Upgrading: $($pkg.Name) ($($pkg.CurrentVersion) -> $($pkg.AvailableVersion))"

            try {
                & choco.exe upgrade $pkg.Name -y --no-progress 2>&1 | Out-Null
                $hasUpgradeFailed = $LASTEXITCODE -ne 0
                if ($hasUpgradeFailed) {
                    Write-Host "  [ WARN ] " -ForegroundColor Yellow -NoNewline
                    Write-Host "$($pkg.Name) upgrade returned exit code $LASTEXITCODE"
                    $failCount++
                } else {
                    Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
                    Write-Host "$($pkg.Name) upgraded"
                    $successCount++
                }
            } catch {
                Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
                Write-Host "Failed to upgrade $($pkg.Name): $_"
                $failCount++
            }
        }

        Write-Host ""
        Write-Host "  ======================================" -ForegroundColor DarkGray
        Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
        Write-Host "$successCount of $($outdated.Count) upgraded successfully"
        if ($failCount -gt 0) {
            Write-Host "  [ WARN ] " -ForegroundColor Yellow -NoNewline
            Write-Host "$failCount package(s) failed"
        }
    } else {
        Write-Host "Running: choco upgrade all -y"
        Write-Host ""

        try {
            & choco.exe upgrade all -y
            $hasUpgradeFailed = $LASTEXITCODE -ne 0
            if ($hasUpgradeFailed) {
                Write-Host ""
                Write-Host "  [ WARN ] " -ForegroundColor Yellow -NoNewline
                Write-Host "Some packages may have failed to upgrade (exit code: $LASTEXITCODE)"
            } else {
                Write-Host ""
                Write-Host "  [  OK  ] " -ForegroundColor Green -NoNewline
                Write-Host "All packages upgraded successfully"
            }
        } catch {
            Write-Host ""
            Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
            Write-Host "Upgrade failed: $_"
        }
    }
}
