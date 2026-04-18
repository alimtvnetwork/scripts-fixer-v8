# --------------------------------------------------------------------------
#  Shared helper: aria2c accelerated downloads
#  Installs aria2c via Chocolatey if missing, then uses it for fast parallel
#  downloads. Falls back to Invoke-DownloadWithRetry when aria2c is unavailable.
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = $PSScriptRoot
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

$_chocoUtilsPath = Join-Path $_sharedDir "choco-utils.ps1"
if ((Test-Path $_chocoUtilsPath) -and -not (Get-Command Assert-Choco -ErrorAction SilentlyContinue)) {
    . $_chocoUtilsPath
}

$_downloadRetryPath = Join-Path $_sharedDir "download-retry.ps1"
if ((Test-Path $_downloadRetryPath) -and -not (Get-Command Invoke-DownloadWithRetry -ErrorAction SilentlyContinue)) {
    . $_downloadRetryPath
}

function Assert-Aria2c {
    <#
    .SYNOPSIS
        Ensures aria2c is installed. Installs via Chocolatey if missing.
        Returns $true if available, $false otherwise.
    #>

    $aria2Cmd = Get-Command aria2c.exe -ErrorAction SilentlyContinue
    if ($aria2Cmd) {
        $version = & aria2c.exe --version 2>&1 | Select-Object -First 1
        Write-Log "aria2c found: $version" -Level "success"
        return $true
    }

    Write-Log "aria2c not found. Installing via Chocolatey..." -Level "info"

    $isChocoOk = Assert-Choco
    if (-not $isChocoOk) {
        Write-Log "Cannot install aria2c: Chocolatey unavailable." -Level "warn"
        return $false
    }

    try {
        & choco.exe install aria2 -y --no-progress 2>&1 | Out-Null

        # Refresh PATH so we can find the new binary
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $aria2Cmd = Get-Command aria2c.exe -ErrorAction SilentlyContinue
        $isInstallOk = $null -ne $aria2Cmd
        if ($isInstallOk) {
            Write-Log "aria2c installed successfully." -Level "success"
            return $true
        } else {
            Write-Log "aria2c install completed but binary not found in PATH." -Level "warn"
            return $false
        }
    } catch {
        Write-Log "aria2c installation failed: $_" -Level "warn"
        return $false
    }
}

function Invoke-Aria2Download {
    <#
    .SYNOPSIS
        Downloads a file using aria2c with multi-connection acceleration.
        Falls back to Invoke-DownloadWithRetry if aria2c is unavailable.

    .PARAMETER Uri
        The download URL.

    .PARAMETER OutFile
        Full path for the output file.

    .PARAMETER Label
        Friendly name for logging.

    .PARAMETER MaxConnections
        Number of connections per server (default: 16).

    .PARAMETER MaxDownloads
        Number of parallel download segments (default: 16).

    .PARAMETER ChunkSize
        Download chunk size (default: "1M").

    .PARAMETER ContinueDownload
        Whether to continue partial downloads (default: $true).

    .RETURNS
        $true on success, $false on failure.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [string]$Label = "",

        [int]$MaxConnections = 16,

        [int]$MaxDownloads = 16,

        [string]$ChunkSize = "1M",

        [bool]$ContinueDownload = $true
    )

    $displayLabel = if ($Label) { $Label } else { [System.IO.Path]::GetFileName($OutFile) }

    # Ensure output directory exists
    $outDir = Split-Path -Parent $OutFile
    $isDirMissing = -not (Test-Path $outDir)
    if ($isDirMissing) {
        New-Item -Path $outDir -ItemType Directory -Force | Out-Null
    }

    # Check if aria2c is available
    $aria2Cmd = Get-Command aria2c.exe -ErrorAction SilentlyContinue
    $isAria2Available = $null -ne $aria2Cmd

    if (-not $isAria2Available) {
        Write-Log "aria2c unavailable, falling back to Invoke-DownloadWithRetry for: $displayLabel" -Level "warn"
        return Invoke-DownloadWithRetry -Uri $Uri -OutFile $OutFile -Label $displayLabel
    }

    Write-Log "Downloading via aria2c ($MaxConnections connections): $displayLabel" -Level "info"

    $outFileName = [System.IO.Path]::GetFileName($OutFile)
    $args = @(
        "-x$MaxConnections",
        "-s$MaxDownloads",
        "-k$ChunkSize",
        "--file-allocation=none",
        "--max-tries=3",
        "--retry-wait=5",
        "--timeout=60",
        "-d", $outDir,
        "-o", $outFileName
    )

    if ($ContinueDownload) {
        $args += "--continue=true"
    }

    $args += $Uri

    try {
        $process = Start-Process -FilePath "aria2c.exe" -ArgumentList $args -NoNewWindow -Wait -PassThru
        $isExitOk = $process.ExitCode -eq 0
        if (-not $isExitOk) {
            Write-Log "aria2c exited with code $($process.ExitCode) for: $displayLabel" -Level "warn"
            # Fallback
            Write-Log "Retrying with Invoke-DownloadWithRetry..." -Level "info"
            return Invoke-DownloadWithRetry -Uri $Uri -OutFile $OutFile -Label $displayLabel
        }

        $isFilePresent = Test-Path $OutFile
        $isFileValid = $isFilePresent -and (Get-Item $OutFile).Length -gt 0
        if (-not $isFileValid) {
            Write-Log "aria2c completed but file is missing or empty: $OutFile" -Level "warn"
            return $false
        }

        Write-Log "Download complete via aria2c: $displayLabel" -Level "success"
        return $true
    } catch {
        Write-Log "aria2c error for $displayLabel -- $_. Falling back..." -Level "warn"
        return Invoke-DownloadWithRetry -Uri $Uri -OutFile $OutFile -Label $displayLabel
    }
}
