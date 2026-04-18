<#
.SYNOPSIS
    Shared helper for writing runtime-resolved data to .resolved/ at repo root.

.DESCRIPTION
    Scripts should never mutate their own config.json with discovered paths.
    Instead, call Save-ResolvedData to persist runtime state to:
        <repo-root>/.resolved/<script-folder>/resolved.json

    The .resolved/ folder is gitignored and safe to overwrite on every run.
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

function Get-ResolvedDir {
    <#
    .SYNOPSIS
        Returns the .resolved/<script-folder> directory path, creating it if needed.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptDir
    )

    $slm = $script:SharedLogMessages

    $repoRoot    = Split-Path -Parent (Split-Path -Parent $ScriptDir)
    $scriptName  = Split-Path -Leaf $ScriptDir
    $resolvedDir = Join-Path $repoRoot ".resolved" | Join-Path -ChildPath $scriptName

    $isDirMissing = -not (Test-Path $resolvedDir)
    if ($isDirMissing) {
        New-Item -Path $resolvedDir -ItemType Directory -Force -Confirm:$false | Out-Null
        Write-Log ($slm.messages.resolvedDirCreated -replace '\{path\}', $resolvedDir) -Level "info"
    }

    return $resolvedDir
}

function Save-ResolvedData {
    <#
    .SYNOPSIS
        Writes a hashtable as JSON to .resolved/<script-folder>/resolved.json.
        Uses -ScriptFolder (folder name string) to locate the output directory.
    #>
    param(
        [string]$ScriptDir,
        [string]$ScriptFolder,

        [Parameter(Mandatory)]
        $Data
    )

    $slm = $script:SharedLogMessages

    # Resolve the directory path
    $hasScriptFolder = $ScriptFolder -and -not $ScriptDir
    if ($hasScriptFolder) {
        # Derive from ScriptFolder name: walk up to repo root from the calling script
        $callerDir = if ($script:ScriptDir) { $script:ScriptDir }
                     elseif ($scriptDir) { $scriptDir }
                     else { Split-Path -Parent $MyInvocation.PSCommandPath }
        $repoRoot    = Split-Path -Parent (Split-Path -Parent $callerDir)
        $resolvedDir = Join-Path $repoRoot ".resolved" | Join-Path -ChildPath $ScriptFolder

        $isDirMissing = -not (Test-Path $resolvedDir)
        if ($isDirMissing) {
            New-Item -Path $resolvedDir -ItemType Directory -Force -Confirm:$false | Out-Null
        }
    }
    else {
        $resolvedDir = Get-ResolvedDir -ScriptDir $ScriptDir
    }

    $resolvedFile = Join-Path $resolvedDir "resolved.json"

    # Merge with existing data if present
    $existing = @{}
    $hasExistingFile = Test-Path $resolvedFile
    if ($hasExistingFile) {
        try {
            $raw = Get-Content $resolvedFile -Raw | ConvertFrom-Json
            foreach ($prop in $raw.PSObject.Properties) {
                $existing[$prop.Name] = $prop.Value
            }
        } catch {
            Write-FileError -FilePath $resolvedFile -Operation "read" -Reason "Could not parse existing resolved.json: $_" -Module "Save-ResolvedData"
            Write-Log $slm.messages.resolvedReadFailed -Level "warn"
        }
    }

    # Overlay new data
    foreach ($key in $Data.Keys) {
        $existing[$key] = $Data[$key]
    }

    try {
        $json = $existing | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($resolvedFile, $json)
        Write-Log ($slm.messages.resolvedSaved -replace '\{path\}', $resolvedFile) -Level "success"
    } catch {
        Write-FileError -FilePath $resolvedFile -Operation "write" -Reason "Failed to write resolved.json: $_" -Module "Save-ResolvedData"
        Write-Log ($slm.messages.resolvedSaveFailed -replace '\{error\}', $_) -Level "warn"
    }
}

function Remove-ResolvedData {
    <#
    .SYNOPSIS
        Deletes the .resolved/<script-folder>/resolved.json file and its directory.
        Returns $true if removed, $false if not found.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptFolder
    )

    $slm = $script:SharedLogMessages

    # Derive repo root from shared dir location
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $resolvedDir = Join-Path $repoRoot ".resolved" | Join-Path -ChildPath $ScriptFolder

    $isDirPresent = Test-Path $resolvedDir
    if ($isDirPresent) {
        Remove-Item -Path $resolvedDir -Recurse -Force
        Write-Log "Removed resolved data: .resolved/$ScriptFolder" -Level "info"
        return $true
    }

    Write-Log "No resolved data found for '$ScriptFolder' -- nothing to remove" -Level "info"
    return $false
}
