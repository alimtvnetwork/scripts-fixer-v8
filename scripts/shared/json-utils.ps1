<#
.SYNOPSIS
    Shared JSON and file utilities used by multiple scripts.
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

function Backup-File {
    param([string]$FilePath, [string]$BackupSuffix)

    $slm = $script:SharedLogMessages

    Write-Log ($slm.messages.backupChecking -replace '\{path\}', $FilePath) -Level "info"
    if (Test-Path $FilePath) {
        $dir       = Split-Path $FilePath -Parent
        $name      = Split-Path $FilePath -Leaf
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupName = "$name.$timestamp$BackupSuffix"
        $backupPath = Join-Path $dir $backupName
        Write-Log ($slm.messages.backupDest -replace '\{path\}', $backupPath) -Level "info"
        try {
            Copy-Item -Path $FilePath -Destination $backupPath -Force
            Write-Log ($slm.messages.backupCreated -replace '\{name\}', $backupName) -Level "success"
            return $true
        } catch {
            Write-FileError -FilePath $FilePath -Operation "copy" -Reason "Backup copy failed: $_" -Module "Backup-File"
            Write-Log ($slm.messages.backupFailed -replace '\{name\}', $name -replace '\{error\}', $_) -Level "error"
            return $false
        }
    } else {
        Write-Log ($slm.messages.backupNotNeeded -replace '\{name\}', (Split-Path $FilePath -Leaf)) -Level "info"
        return $true
    }
}

function ConvertTo-OrderedHashtable {
    param([Parameter(Mandatory)][PSCustomObject]$InputObject)

    $ht = [ordered]@{}
    foreach ($prop in $InputObject.PSObject.Properties) {
        if ($prop.Value -is [PSCustomObject]) {
            $ht[$prop.Name] = ConvertTo-OrderedHashtable -InputObject $prop.Value
        } else {
            $ht[$prop.Name] = $prop.Value
        }
    }
    return $ht
}

function Merge-JsonDeep {
    param(
        [Parameter(Mandatory)]
        $Base,
        [Parameter(Mandatory)]
        $Override
    )

    $result = $Base.Clone()
    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and
            $result[$key] -is [hashtable] -and
            $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-JsonDeep -Base $result[$key] -Override $Override[$key]
        } else {
            $result[$key] = $Override[$key]
        }
    }
    return $result
}
