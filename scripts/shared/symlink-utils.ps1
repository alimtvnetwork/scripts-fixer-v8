<#
.SYNOPSIS
    Shared helper for creating directory junctions from dev directory
    to actual database install locations.

.DESCRIPTION
    After Chocolatey installs a database to its default system location,
    this helper creates a directory junction (symlink) from
    E:\dev-tool\databases\<name> -> actual install path, so all databases
    appear organized under the dev directory.
#>

# -- Bootstrap shared helpers --------------------------------------------------
$loggingPath = Join-Path $PSScriptRoot "logging.ps1"
if ((Test-Path $loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $loggingPath
}

if (-not (Get-Variable -Name SharedLogMessages -Scope Script -ErrorAction SilentlyContinue)) {
    $sharedLogPath = Join-Path $PSScriptRoot "log-messages.json"
    if (Test-Path $sharedLogPath) {
        $script:SharedLogMessages = Get-Content $sharedLogPath -Raw | ConvertFrom-Json
    }
}

function Resolve-DbInstallDir {
    <#
    .SYNOPSIS
        Resolves the actual install directory for a database by finding its
        executable via Get-Command and walking up to the install root.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$VerifyCommand
    )

    $cmd = Get-Command $VerifyCommand -ErrorAction SilentlyContinue
    $hasNoCommand = -not $cmd
    if ($hasNoCommand) { return $null }

    $exePath = $cmd.Source
    $hasNoSource = [string]::IsNullOrWhiteSpace($exePath)
    if ($hasNoSource) { return $null }

    $binDir = Split-Path -Parent $exePath

    # Walk up from the bin directory to find the install root.
    # Common patterns:
    #   ...\MySQL\MySQL Server 8.0\bin\mysql.exe  -> ...\MySQL\MySQL Server 8.0
    #   ...\PostgreSQL\16\bin\psql.exe             -> ...\PostgreSQL\16
    #   ...\chocolatey\lib\duckdb\tools\duckdb.exe -> ...\chocolatey\lib\duckdb
    #   ...\Redis\redis-server.exe                 -> ...\Redis

    $dirName = (Split-Path -Leaf $binDir).ToLower()
    $isBinDir = $dirName -eq "bin"
    if ($isBinDir) {
        return Split-Path -Parent $binDir
    }

    # Check if parent looks like a tools dir (Chocolatey pattern)
    $isToolsDir = $dirName -eq "tools"
    if ($isToolsDir) {
        return Split-Path -Parent $binDir
    }

    # Otherwise the exe is directly in the install dir
    return $binDir
}

function New-DbSymlink {
    <#
    .SYNOPSIS
        Creates a directory junction from $DevDir\databases\$Name to the
        actual install location of a database.

    .DESCRIPTION
        1. Resolves the actual install dir from the verify command
        2. Creates $DevDir\databases\ if missing
        3. Creates a junction: $DevDir\databases\$Name -> actual path
        4. Skips if junction already exists and points to the correct target

    .RETURNS
        $true if junction was created or already correct, $false on failure.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$VerifyCommand,

        [Parameter(Mandatory)]
        [string]$DevDir
    )

    $slm = $script:SharedLogMessages

    # Resolve actual install location
    $actualDir = Resolve-DbInstallDir -VerifyCommand $VerifyCommand
    $hasNoActualDir = -not $actualDir -or -not (Test-Path $actualDir)
    if ($hasNoActualDir) {
        $resolvedPath = if ($actualDir) { $actualDir } else { "(could not resolve from command: $VerifyCommand)" }
        Write-FileError -FilePath $resolvedPath -Operation "resolve" -Reason "Install directory does not exist or could not be resolved from verify command '$VerifyCommand'" -Module "New-DbSymlink"
        Write-Log ($slm.messages.symlinkSourceNotFound -replace '\{name\}', $Name) -Level "warn"
        return $false
    }

    # Ensure databases parent directory exists
    $dbParentDir = Join-Path $DevDir "databases"
    $isParentMissing = -not (Test-Path $dbParentDir)
    if ($isParentMissing) {
        New-Item -Path $dbParentDir -ItemType Directory -Force | Out-Null
        Write-Log ($slm.messages.symlinkParentCreated -replace '\{path\}', $dbParentDir) -Level "info"
    }

    $junctionPath = Join-Path $dbParentDir $Name

    # Check if junction already exists
    $isJunctionExists = Test-Path $junctionPath
    if ($isJunctionExists) {
        $item = Get-Item $junctionPath -Force
        $isJunction = $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint
        if ($isJunction) {
            $currentTarget = $item.Target
            $isSameTarget = $currentTarget -eq $actualDir
            if ($isSameTarget) {
                Write-Log ($slm.messages.symlinkAlreadyCorrect -replace '\{name\}', $Name -replace '\{path\}', $junctionPath) -Level "info"
                return $true
            }
            # Remove stale junction
            Remove-Item $junctionPath -Force
            Write-Log ($slm.messages.symlinkRemovedStale -replace '\{name\}', $Name) -Level "warn"
        } else {
            # Real directory exists at junction path -- skip
            Write-Log ($slm.messages.symlinkRealDirExists -replace '\{name\}', $Name -replace '\{path\}', $junctionPath) -Level "warn"
            return $false
        }
    }

    # Create junction
    try {
        New-Item -ItemType Junction -Path $junctionPath -Target $actualDir -Force | Out-Null
        Write-Log ($slm.messages.symlinkCreated -replace '\{name\}', $Name -replace '\{link\}', $junctionPath -replace '\{target\}', $actualDir) -Level "success"
        return $true
    } catch {
        Write-FileError -FilePath $junctionPath -Operation "write" -Reason "Failed to create junction to '$actualDir': $($_.Exception.Message)" -Module "New-DbSymlink"
        Write-Log ($slm.messages.symlinkFailed -replace '\{name\}', $Name -replace '\{error\}', $_.Exception.Message) -Level "error"
        return $false
    }
}
