# --------------------------------------------------------------------------
#  Scripts Fixer -- One-liner bootstrap installer
#  Usage:  irm https://raw.githubusercontent.com/alimtvnetwork/scripts-fixer-v7/main/install.ps1 | iex
#
#  Auto-discovery: probes scripts-fixer-vN repos (N = current+1..current+30)
#  in parallel and redirects to the newest published version.
#  Spec: spec/install-bootstrap/readme.md
#  Disable with: -NoUpgrade  or  $env:SCRIPTS_FIXER_NO_UPGRADE = "1"
#  Version check: -Version (shows current and latest, no install)
# --------------------------------------------------------------------------
& {
    param([switch]$NoUpgrade, [switch]$Version, [switch]$DryRun)

    $ErrorActionPreference = "Stop"

    # ----- Configuration ----------------------------------------------------
    $owner    = "alimtvnetwork"
    $baseName = "scripts-fixer"
    $current  = 8   # <-- bump this when this file is copied into a new -vN repo
    $folder   = Join-Path $env:USERPROFILE "scripts-fixer"
    $repo     = "https://github.com/$owner/$baseName-v$current.git"

    $probeMax = 30
    if ($env:SCRIPTS_FIXER_PROBE_MAX) {
        $parsed = 0
        if ([int]::TryParse($env:SCRIPTS_FIXER_PROBE_MAX, [ref]$parsed) -and $parsed -gt 0 -and $parsed -le 100) {
            $probeMax = $parsed
        }
    }

    Write-Host ""
    Write-Host "  Scripts Fixer -- Bootstrap Installer (v$current)" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "  [DRYRUN] Dry-run mode ON -- nothing will be cloned, removed, copied, or executed." -ForegroundColor Magenta
    }
    Write-Host ""

    # ----- Version check mode (discover + report, no clone) ----------------
    if ($Version) {
        $rangeEnd = $current + $probeMax
        Write-Host "  [VERSION] Bootstrap v$current" -ForegroundColor Cyan
        Write-Host "  [SCAN] Probing v$($current + 1)..v$rangeEnd for newer releases (parallel)..." -ForegroundColor Yellow

        $hasThreadJob = $null -ne (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)
        $found = @()

        try {
            if ($hasThreadJob) {
                $jobs = @()
                foreach ($n in ($current + 1)..$rangeEnd) {
                    $url = "https://raw.githubusercontent.com/$owner/$baseName-v$n/main/install.ps1"
                    $jobs += Start-ThreadJob -ScriptBlock {
                        param($u, $v)
                        try {
                            $r = Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                            if ($r.StatusCode -eq 200) { return $v }
                        } catch {}
                        return $null
                    } -ArgumentList $url, $n
                }
                $results = $jobs | Wait-Job -Timeout 15 | Receive-Job
                $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
                $found = @($results | Where-Object { $null -ne $_ })
            } else {
                foreach ($n in ($current + 1)..$rangeEnd) {
                    $url = "https://raw.githubusercontent.com/$owner/$baseName-v$n/main/install.ps1"
                    try {
                        $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
                        if ($r.StatusCode -eq 200) { $found += $n }
                    } catch {}
                }
            }
        } catch {
            Write-Host "  [WARN] Discovery failed: $_" -ForegroundColor Yellow
        }

        if ($found.Count -gt 0) {
            $latest = ($found | Measure-Object -Maximum).Maximum
            if ($latest -gt $current) {
                Write-Host "  [FOUND] Newer version available: v$latest" -ForegroundColor Green
                Write-Host "  [RESOLVED] Would redirect to $baseName-v$latest" -ForegroundColor Cyan
            } else {
                Write-Host "  [OK] You're on the latest (v$current)" -ForegroundColor Green
            }
        } else {
            Write-Host "  [OK] You're on the latest (v$current)" -ForegroundColor Green
        }
        Write-Host ""
        Write-Host "  (Use without -Version flag to actually install)" -ForegroundColor DarkGray
        return
    }

    # ----- Auto-discovery: probe for newer -vN repos -----------------------
    $skipDiscovery = $NoUpgrade -or $env:SCRIPTS_FIXER_NO_UPGRADE -eq "1" -or $env:SCRIPTS_FIXER_REDIRECTED -eq "1"

    if ($skipDiscovery) {
        if ($env:SCRIPTS_FIXER_REDIRECTED -eq "1") {
            Write-Host "  [SKIP] Auto-discovery skipped (already redirected)." -ForegroundColor DarkGray
        } else {
            Write-Host "  [SKIP] Auto-discovery disabled." -ForegroundColor DarkGray
        }
    } else {
        $rangeEnd = $current + $probeMax
        Write-Host "  [SCAN] Currently on v$current. Probing v$($current + 1)..v$rangeEnd for newer releases (parallel)..." -ForegroundColor Yellow

        $hasThreadJob = $null -ne (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)
        $found = @()

        try {
            if ($hasThreadJob) {
                $jobs = @()
                foreach ($n in ($current + 1)..$rangeEnd) {
                    $url = "https://raw.githubusercontent.com/$owner/$baseName-v$n/main/install.ps1"
                    $jobs += Start-ThreadJob -ScriptBlock {
                        param($u, $v)
                        try {
                            $r = Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                            if ($r.StatusCode -eq 200) { return $v }
                        } catch {}
                        return $null
                    } -ArgumentList $url, $n
                }
                $results = $jobs | Wait-Job -Timeout 15 | Receive-Job
                $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
                $found = @($results | Where-Object { $null -ne $_ })
            } else {
                # Sequential fallback (Windows PowerShell 5.1 without ThreadJob module)
                foreach ($n in ($current + 1)..$rangeEnd) {
                    $url = "https://raw.githubusercontent.com/$owner/$baseName-v$n/main/install.ps1"
                    try {
                        $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
                        if ($r.StatusCode -eq 200) { $found += $n }
                    } catch {}
                }
            }
        } catch {
            Write-Host "  [WARN] Discovery failed: $_  -- continuing with v$current" -ForegroundColor Yellow
            $found = @()
        }

        if ($found.Count -gt 0) {
            $latest = ($found | Measure-Object -Maximum).Maximum
            if ($latest -gt $current) {
                Write-Host "  [FOUND] Newer version available: v$latest" -ForegroundColor Green
                Write-Host "  [REDIRECT] Switching to $baseName-v$latest..." -ForegroundColor Cyan
                Write-Host ""
                $env:SCRIPTS_FIXER_REDIRECTED = "1"
                $newUrl = "https://raw.githubusercontent.com/$owner/$baseName-v$latest/main/install.ps1"
                try {
                    $script = (Invoke-WebRequest -Uri $newUrl -UseBasicParsing -TimeoutSec 15).Content
                    Invoke-Expression $script
                    return
                } catch {
                    Write-Host "  [WARN] Failed to fetch v$latest installer: $_  -- falling back to v$current" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [OK] You're on the latest (v$current). Continuing..." -ForegroundColor Green
            }
        } else {
            Write-Host "  [OK] You're on the latest (v$current). Continuing..." -ForegroundColor Green
        }
        Write-Host ""
    }

    # ----- Check git is available ------------------------------------------
    $hasGit = Get-Command git -ErrorAction SilentlyContinue
    if (-not $hasGit) {
        Write-Host "  [ERROR] git is not installed. Install Git first, then re-run." -ForegroundColor Red
        Write-Host "          winget install Git.Git" -ForegroundColor DarkGray
        return
    }

    # ----- Helper: invoke git cleanly (silences stderr-as-error noise) -----
    function Invoke-GitClone {
        param([string]$RepoUrl, [string]$TargetPath, [bool]$IsDryRun)
        Write-Host "  [GIT] Cloning from : $RepoUrl" -ForegroundColor Cyan
        Write-Host "  [GIT] Cloning into : $TargetPath" -ForegroundColor Cyan
        if ($IsDryRun) {
            Write-Host "  [DRYRUN] git clone --quiet $RepoUrl $TargetPath  (skipped)" -ForegroundColor Magenta
            # Simulate successful clone so downstream flow logs the rest of the path
            return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = ''; DryRun = $true }
        }
        $errFile = [System.IO.Path]::GetTempFileName()
        try {
            # Redirect stderr to file so PowerShell does NOT raise NativeCommandError
            # on git's normal progress messages. Capture stdout for diagnostics.
            $stdout = & git clone --quiet $RepoUrl $TargetPath 2>$errFile
            $exit = $LASTEXITCODE
            $stderr = if (Test-Path $errFile) { Get-Content $errFile -Raw } else { "" }
            return [pscustomobject]@{ ExitCode = $exit; StdOut = $stdout; StdErr = $stderr; DryRun = $false }
        } finally {
            Remove-Item $errFile -Force -ErrorAction SilentlyContinue
        }
    }

    # ----- Helper: safe remove with read-only attribute clearing -----------
    function Remove-FolderSafe {
        param([string]$Path, [bool]$IsDryRun)
        if (-not (Test-Path $Path)) { return $true }
        if ($IsDryRun) {
            Write-Host "  [DRYRUN] Would remove folder: $Path  (skipped)" -ForegroundColor Magenta
            return $true
        }
        try {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            return $true
        } catch {
            Write-Host "  [WARN] Could not remove $Path" -ForegroundColor Yellow
            Write-Host "         Reason: $_" -ForegroundColor DarkGray
            return $false
        }
    }

    # ----- Detect self-location (CWD is target OR sibling 'scripts-fixer') -
    $cwd            = (Get-Location).Path
    $cwdLeaf        = Split-Path $cwd -Leaf
    $isInsideTarget = ($cwdLeaf -ieq 'scripts-fixer')
    $hasSibling     = Test-Path (Join-Path $cwd 'scripts-fixer')
    $needsRelocate  = $isInsideTarget -or $hasSibling

    Write-Host ""
    Write-Host "  [LOCATE] Current directory : $cwd" -ForegroundColor DarkGray
    Write-Host "  [LOCATE] Target folder     : $folder" -ForegroundColor DarkGray
    if ($isInsideTarget) {
        Write-Host "  [LOCATE] You are INSIDE a 'scripts-fixer' folder -- using relocation flow." -ForegroundColor Yellow
    } elseif ($hasSibling) {
        Write-Host "  [LOCATE] A 'scripts-fixer' folder exists in CWD -- using relocation flow." -ForegroundColor Yellow
    } else {
        Write-Host "  [LOCATE] No conflict detected -- using direct clone flow." -ForegroundColor DarkGray
    }

    # ----- Step out of folder if we're sitting inside it -------------------
    if ($isInsideTarget) {
        $parent = Split-Path $cwd -Parent
        Write-Host "  [CD] Stepping out to parent  : $parent" -ForegroundColor Yellow
        if ($DryRun) {
            Write-Host "  [DRYRUN] Set-Location $parent  (skipped)" -ForegroundColor Magenta
        } else {
            Set-Location $parent
        }
    }

    # ----- Try to remove existing target folder ----------------------------
    $removed = $true
    if (Test-Path $folder) {
        Write-Host "  [CLEAN] Removing existing folder: $folder" -ForegroundColor Yellow
        $removed = Remove-FolderSafe -Path $folder -IsDryRun:$DryRun
        if ($removed) {
            if ($DryRun) {
                Write-Host "  [DRYRUN] (would have removed) Folder: $folder" -ForegroundColor Magenta
            } else {
                Write-Host "  [OK] Folder removed." -ForegroundColor Green
            }
        } else {
            Write-Host "  [INFO] Direct removal failed -- will use TEMP staging fallback." -ForegroundColor Yellow
        }
    }

    # ----- Direct clone path (no conflict OR remove succeeded) -------------
    if ($removed) {
        Write-Host ""
        Write-Host "  [>>] Direct clone into target..." -ForegroundColor Yellow
        $r = Invoke-GitClone -RepoUrl $repo -TargetPath $folder -IsDryRun:$DryRun
        if (-not $DryRun) {
            if ($r.ExitCode -ne 0 -or -not (Test-Path (Join-Path $folder ".git"))) {
                Write-Host "  [ERROR] Clone failed (exit $($r.ExitCode))" -ForegroundColor Red
                Write-Host "          Repo   : $repo" -ForegroundColor Red
                Write-Host "          Target : $folder" -ForegroundColor Red
                if ($r.StdErr) {
                    Write-Host "          Git stderr:" -ForegroundColor DarkGray
                    ($r.StdErr -split "`n") | ForEach-Object { if ($_.Trim()) { Write-Host "            $_" -ForegroundColor DarkGray } }
                }
                Write-Host "          Verify the repo exists and your network is reachable." -ForegroundColor DarkGray
                return
            }
            Write-Host "  [OK] Cloned successfully into $folder" -ForegroundColor Green
        }
    }
    else {
        # ----- TEMP staging fallback (remove failed -- folder is locked) ---
        $stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
        $tempDir = Join-Path $env:TEMP "scripts-fixer-bootstrap-$stamp"
        Write-Host ""
        Write-Host "  [TEMP] Staging clone path  : $tempDir" -ForegroundColor Yellow
        $r = Invoke-GitClone -RepoUrl $repo -TargetPath $tempDir -IsDryRun:$DryRun
        if (-not $DryRun) {
            if ($r.ExitCode -ne 0 -or -not (Test-Path (Join-Path $tempDir ".git"))) {
                Write-Host "  [ERROR] Temp clone failed (exit $($r.ExitCode))" -ForegroundColor Red
                Write-Host "          Repo   : $repo" -ForegroundColor Red
                Write-Host "          Target : $tempDir" -ForegroundColor Red
                if ($r.StdErr) {
                    Write-Host "          Git stderr:" -ForegroundColor DarkGray
                    ($r.StdErr -split "`n") | ForEach-Object { if ($_.Trim()) { Write-Host "            $_" -ForegroundColor DarkGray } }
                }
                return
            }
            Write-Host "  [OK] Temp clone complete." -ForegroundColor Green
        }

        # Copy contents over the locked folder (overwrite)
        Write-Host "  [COPY] From : $tempDir" -ForegroundColor Yellow
        Write-Host "  [COPY] To   : $folder" -ForegroundColor Yellow
        if ($DryRun) {
            Write-Host "  [DRYRUN] Copy-Item -Recurse -Force from $tempDir to $folder  (skipped)" -ForegroundColor Magenta
        } else {
            if (-not (Test-Path $folder)) {
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
            }
            try {
                Copy-Item -Path (Join-Path $tempDir '*') -Destination $folder -Recurse -Force -ErrorAction Stop
                Write-Host "  [OK] Files copied into $folder" -ForegroundColor Green
            } catch {
                Write-Host "  [ERROR] Copy from temp failed." -ForegroundColor Red
                Write-Host "          Source : $tempDir" -ForegroundColor Red
                Write-Host "          Target : $folder" -ForegroundColor Red
                Write-Host "          Reason : $_" -ForegroundColor Red
                Write-Host "          Files remain in temp -- copy manually if needed." -ForegroundColor DarkGray
                return
            }

            # Best-effort cleanup of temp staging
            Remove-FolderSafe -Path $tempDir -IsDryRun:$false | Out-Null
            Write-Host "  [CLEAN] Temp staging removed." -ForegroundColor DarkGray
        }
    }

    # ----- Launch interactive menu -----------------------------------------
    Write-Host ""
    Write-Host "  [CD] Entering              : $folder" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "  [DRYRUN] Set-Location $folder  (skipped)" -ForegroundColor Magenta
        Write-Host "  [DRYRUN] & .\run.ps1 -d  (skipped)" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "  [DRYRUN] Dry-run complete. Re-run without -DryRun to actually install." -ForegroundColor Magenta
        Write-Host ""
        return
    }
    Set-Location $folder
    Write-Host "  Launching interactive menu..." -ForegroundColor Cyan
    Write-Host ""
    & .\run.ps1 -d
} @args
