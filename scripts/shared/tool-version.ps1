# --------------------------------------------------------------------------
#  Assert-ToolVersion -- Shared helper for version detection + tracking
#  Extracts the repeated pattern of "run --version, guard empty, check tracking"
#  into a reusable function.
# --------------------------------------------------------------------------

function Assert-ToolVersion {
    <#
    .SYNOPSIS
        Runs a tool's version command, guards against empty output, checks
        .installed/ tracking, and returns a result object.

    .DESCRIPTION
        Consolidates the repeated pattern across all install helpers:
        1. Run `<command> <versionFlag>` (e.g. `python --version`)
        2. Guard against empty/null output
        3. Check .installed/ tracking via Test-AlreadyInstalled
        4. Return a structured result

    .PARAMETER Name
        The tracking name (e.g. "python", "nodejs", "git"). Used for .installed/<name>.json.

    .PARAMETER Command
        The executable command to run (e.g. "python", "node", "git").

    .PARAMETER VersionFlag
        The flag to get version output (default: "--version").

    .PARAMETER ParseScript
        Optional scriptblock to parse the raw version output.
        Receives the raw string and should return a cleaned version string.
        Example: { param($raw) $raw -replace 'Python ', '' }

    .OUTPUTS
        Hashtable with:
          - Exists    [bool]   : Whether the command was found in PATH
          - Version   [string] : The detected version string (or $null)
          - HasVersion [bool]  : Whether a non-empty version was detected
          - IsTracked [bool]   : Whether this exact version is already tracked
          - Raw       [string] : The raw output from the version command

    .EXAMPLE
        $result = Assert-ToolVersion -Name "python" -Command "python"
        if ($result.IsTracked) { Write-Log "Already installed"; return }

    .EXAMPLE
        $result = Assert-ToolVersion -Name "nodejs" -Command "node" -ParseScript {
            param($raw) ($raw -replace 'v', '').Trim()
        }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Command,

        [string]$VersionFlag = "--version",

        [scriptblock]$ParseScript = $null
    )

    $result = @{
        Exists     = $false
        Version    = $null
        HasVersion = $false
        IsTracked  = $false
        Raw        = $null
    }

    # Check if command exists
    $cmdInfo = Get-Command $Command -ErrorAction SilentlyContinue
    $isCommandMissing = -not $cmdInfo
    if ($isCommandMissing) {
        return $result
    }

    $result.Exists = $true

    # Get version output with defensive try/catch
    $rawOutput = $null
    try {
        $rawOutput = & $Command $VersionFlag 2>$null
    } catch {
        # Command exists but version flag failed
    }

    $result.Raw = $rawOutput

    # Parse version
    $version = $rawOutput
    $hasParseScript = $null -ne $ParseScript
    if ($hasParseScript -and $rawOutput) {
        try {
            $version = & $ParseScript $rawOutput
        } catch {
            $version = $rawOutput
        }
    }

    # Clean up
    $isVersionEmpty = [string]::IsNullOrWhiteSpace($version)
    if ($isVersionEmpty) {
        return $result
    }

    $result.Version = "$version".Trim()
    $result.HasVersion = $true

    # Check tracking
    $result.IsTracked = Test-AlreadyInstalled -Name $Name -CurrentVersion $result.Version

    return $result
}


function Refresh-EnvPath {
    <#
    .SYNOPSIS
        Refreshes $env:Path from Machine + User registry values.
        Call after installs/upgrades so newly installed tools are discoverable.
    #>
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}


function Get-PersistedEnvironmentVariableValue {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )

    $value = [System.Environment]::GetEnvironmentVariable($Name, $Scope)
    $hasValue = -not [string]::IsNullOrWhiteSpace($value)
    if (-not $hasValue) {
        return $null
    }

    return $value.Trim()
}


function Get-PythonResolverCache {
    $cacheVariable = Get-Variable -Name "_ScriptsFixerResolvedPythonInfo" -Scope Global -ErrorAction SilentlyContinue
    $hasCacheVariable = $null -ne $cacheVariable
    if ($hasCacheVariable) {
        return $cacheVariable.Value
    }

    return $null
}

function Set-PythonResolverCache {
    param(
        $PythonInfo
    )

    Set-Variable -Name "_ScriptsFixerResolvedPythonInfo" -Scope Global -Value $PythonInfo -Force
}

function Add-UniquePath {
    param(
        [System.Collections.Generic.List[string]]$Target,

        [string]$Path
    )

    $hasTarget = $null -ne $Target
    $isTargetMissing = -not $hasTarget
    if ($isTargetMissing) {
        return
    }

    $hasPath = -not [string]::IsNullOrWhiteSpace($Path)
    $isPathMissing = -not $hasPath
    if ($isPathMissing) {
        return
    }

    $isAlreadyPresent = $false
    foreach ($existingPath in $Target) {
        $isSamePath = $existingPath -ieq $Path
        if ($isSamePath) {
            $isAlreadyPresent = $true
            break
        }
    }

    if ($isAlreadyPresent) {
        return
    }

    $Target.Add($Path)
}

function Get-CommandSourcePath {
    param(
        [Parameter(Mandatory)]
        $CommandInfo
    )

    foreach ($propertyName in @("Source", "Path", "Definition")) {
        $hasProperty = $CommandInfo.PSObject.Properties.Name -contains $propertyName
        if ($hasProperty) {
            $propertyValue = "$($CommandInfo.$propertyName)".Trim()
            $hasValue = -not [string]::IsNullOrWhiteSpace($propertyValue)
            if ($hasValue) {
                return $propertyValue
            }
        }
    }

    return $null
}

function Test-IsWindowsAppsAliasPath {
    param(
        [string]$Path
    )

    $hasPath = -not [string]::IsNullOrWhiteSpace($Path)
    $isPathMissing = -not $hasPath
    if ($isPathMissing) {
        return $false
    }

    $normalizedPath = $Path -replace '/', '\\'
    $isWindowsAppsAlias = $normalizedPath -match '\\Microsoft\\WindowsApps\\'
    return $isWindowsAppsAlias
}

function Get-ResolvedPathsFromPatterns {
    param(
        [string[]]$Patterns
    )

    $resolvedPaths = [System.Collections.Generic.List[string]]::new()
    $hasPatterns = $null -ne $Patterns -and $Patterns.Count -gt 0
    if (-not $hasPatterns) {
        return @()
    }

    foreach ($pattern in $Patterns) {
        $hasPattern = -not [string]::IsNullOrWhiteSpace($pattern)
        $isPatternMissing = -not $hasPattern
        if ($isPatternMissing) {
            continue
        }

        $items = @(Resolve-Path $pattern -ErrorAction SilentlyContinue)
        foreach ($item in $items) {
            $resolvedPath = "$($item.Path)"
            $isFile = Test-Path $resolvedPath -PathType Leaf
            if ($isFile) {
                Add-UniquePath -Target $resolvedPaths -Path $resolvedPath
            }
        }
    }

    return $resolvedPaths.ToArray()
}

function Test-PythonExecutable {
    param(
        [Parameter(Mandatory)]
        [string]$ExecutablePath,

        [switch]$RequirePip
    )

    $result = @{
        Path       = $ExecutablePath
        Exists     = $false
        Version    = $null
        HasVersion = $false
        PipVersion = $null
        HasPip     = $false
        IsValid    = $false
    }

    $hasExecutablePath = -not [string]::IsNullOrWhiteSpace($ExecutablePath)
    $isExecutablePathMissing = -not $hasExecutablePath
    if ($isExecutablePathMissing) {
        return $result
    }

    $isWindowsAppsAlias = Test-IsWindowsAppsAliasPath -Path $ExecutablePath
    if ($isWindowsAppsAlias) {
        return $result
    }

    $existsOnDisk = Test-Path $ExecutablePath -PathType Leaf
    $isMissingOnDisk = -not $existsOnDisk
    if ($isMissingOnDisk) {
        return $result
    }

    $result.Exists = $true

    $versionOutput = $null
    try {
        # Reset LASTEXITCODE so stale values from prior commands (e.g. choco) don't pollute the check
        $Global:LASTEXITCODE = 0
        $versionOutput = & $ExecutablePath --version 2>&1
    } catch {
    }

    $versionText = "$versionOutput".Trim()
    $hasVersionText = -not [string]::IsNullOrWhiteSpace($versionText)
    $isVersionMatch = $versionText -match '^Python\s+\d'
    $isVersionValid = $hasVersionText -and $LASTEXITCODE -eq 0 -and $isVersionMatch
    if ($isVersionValid) {
        $result.Version = $versionText
        $result.HasVersion = $true
    } else {
        return $result
    }

    $pipOutput = $null
    try {
        $Global:LASTEXITCODE = 0
        $pipOutput = & $ExecutablePath -m pip --version 2>&1
    } catch {
    }

    $pipText = "$pipOutput".Trim()
    $hasPipText = -not [string]::IsNullOrWhiteSpace($pipText)
    $isPipMatch = $pipText -match '^pip\s+\d'
    $isPipValid = $hasPipText -and $LASTEXITCODE -eq 0 -and $isPipMatch
    if ($isPipValid) {
        $result.PipVersion = $pipText
        $result.HasPip = $true
    }

    $isPipRequiredButMissing = $RequirePip -and -not $result.HasPip
    if ($isPipRequiredButMissing) {
        return $result
    }

    $result.IsValid = $true
    return $result
}

function Resolve-PythonExe {
    <#
    .SYNOPSIS
        Resolves a real Python executable, skipping Windows App aliases and
        validating version output before accepting a candidate.

    .PARAMETER RequirePip
        Require `python -m pip --version` to succeed as well.

    .PARAMETER ReturnInfo
        Return the full info hashtable instead of just the executable path.

    .PARAMETER RefreshPath
        Refresh the current process PATH from registry before probing.
    #>
    param(
        [switch]$RequirePip,

        [switch]$ReturnInfo,

        [switch]$RefreshPath
    )

    if ($RefreshPath) {
        Refresh-EnvPath
    }

    $cachedInfo = Get-PythonResolverCache
    $hasCachedInfo = $null -ne $cachedInfo -and $cachedInfo.IsValid
    if ($hasCachedInfo) {
        $validatedCachedInfo = Test-PythonExecutable -ExecutablePath $cachedInfo.Path -RequirePip:$RequirePip
        $hasValidatedCachedInfo = $null -ne $validatedCachedInfo -and $validatedCachedInfo.IsValid
        if ($hasValidatedCachedInfo) {
            Set-PythonResolverCache -PythonInfo $validatedCachedInfo
            $env:PYTHON_EXE = $validatedCachedInfo.Path
            if ($ReturnInfo) {
                return $validatedCachedInfo
            }

            return $validatedCachedInfo.Path
        }
    }

    $candidatePaths = [System.Collections.Generic.List[string]]::new()

    $persistedPythonExeValues = @(
        $env:PYTHON_EXE,
        (Get-PersistedEnvironmentVariableValue -Name "PYTHON_EXE" -Scope "User"),
        (Get-PersistedEnvironmentVariableValue -Name "PYTHON_EXE" -Scope "Machine")
    )
    foreach ($persistedPythonExe in $persistedPythonExeValues) {
        Add-UniquePath -Target $candidatePaths -Path $persistedPythonExe
    }

    $persistedPythonHomes = @(
        $env:PYTHON_HOME,
        (Get-PersistedEnvironmentVariableValue -Name "PYTHON_HOME" -Scope "User"),
        (Get-PersistedEnvironmentVariableValue -Name "PYTHON_HOME" -Scope "Machine")
    )
    foreach ($persistedPythonHome in $persistedPythonHomes) {
        $hasPersistedPythonHome = -not [string]::IsNullOrWhiteSpace($persistedPythonHome)
        if ($hasPersistedPythonHome) {
            $persistedPythonPath = Join-Path $persistedPythonHome "python.exe"
            Add-UniquePath -Target $candidatePaths -Path $persistedPythonPath
        }
    }

    foreach ($commandName in @("python", "python3", "py")) {
        $commandInfos = @(Get-Command $commandName -All -ErrorAction SilentlyContinue)
        foreach ($commandInfo in $commandInfos) {
            $candidatePath = Get-CommandSourcePath -CommandInfo $commandInfo
            Add-UniquePath -Target $candidatePaths -Path $candidatePath
        }
    }

    $fallbackPatterns = @(
        "C:\ProgramData\chocolatey\bin\python.exe",
        "C:\ProgramData\chocolatey\bin\python3.exe",
        "C:\Python*\python.exe"
    )

    $hasChocolateyInstall = -not [string]::IsNullOrWhiteSpace($env:ChocolateyInstall)
    if ($hasChocolateyInstall) {
        $fallbackPatterns += (Join-Path $env:ChocolateyInstall "bin\python.exe")
        $fallbackPatterns += (Join-Path $env:ChocolateyInstall "bin\python3.exe")
        # Chocolatey lib tools path (where the actual python exe lives)
        $fallbackPatterns += (Join-Path $env:ChocolateyInstall "lib\python3\tools\python.exe")
        $fallbackPatterns += (Join-Path $env:ChocolateyInstall "lib\python\tools\python.exe")
        $fallbackPatterns += (Join-Path $env:ChocolateyInstall "lib\python3*\tools\python.exe")
    }

    $hasLocalAppData = -not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)
    if ($hasLocalAppData) {
        $fallbackPatterns += (Join-Path $env:LOCALAPPDATA "Programs\Python\Python*\python.exe")
    }

    $hasProgramFiles = -not [string]::IsNullOrWhiteSpace($env:ProgramFiles)
    if ($hasProgramFiles) {
        $fallbackPatterns += (Join-Path $env:ProgramFiles "Python*\python.exe")
    }

    $programFilesX86 = ${env:ProgramFiles(x86)}
    $hasProgramFilesX86 = -not [string]::IsNullOrWhiteSpace($programFilesX86)
    if ($hasProgramFilesX86) {
        $fallbackPatterns += (Join-Path $programFilesX86 "Python*\python.exe")
    }

    $resolvedFallbackPaths = Get-ResolvedPathsFromPatterns -Patterns $fallbackPatterns
    foreach ($resolvedFallbackPath in $resolvedFallbackPaths) {
        Add-UniquePath -Target $candidatePaths -Path $resolvedFallbackPath
    }

    foreach ($candidatePath in $candidatePaths) {
        $pythonInfo = Test-PythonExecutable -ExecutablePath $candidatePath -RequirePip:$RequirePip
        $hasValidPython = $null -ne $pythonInfo -and $pythonInfo.IsValid
        if ($hasValidPython) {
            Set-PythonResolverCache -PythonInfo $pythonInfo
            $env:PYTHON_EXE = $pythonInfo.Path
            if ($ReturnInfo) {
                return $pythonInfo
            }

            return $pythonInfo.Path
        }
    }

    return $null
}
