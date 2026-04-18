<#
.SYNOPSIS
    Shared --help display helper.

.DESCRIPTION
    Provides Show-ScriptHelp for consistent help output across all scripts.
    Supports two calling conventions:
      Old-style: Show-ScriptHelp -Name -Version -Description -Commands -Flags -Examples
      New-style: Show-ScriptHelp -LogMessages $logMessages
#>

# -- Bootstrap shared log messages --------------------------------------------
if (-not (Get-Variable -Name SharedLogMessages -Scope Script -ErrorAction SilentlyContinue)) {
    $sharedLogPath = Join-Path $PSScriptRoot "log-messages.json"
    $isSharedLogFound = Test-Path $sharedLogPath
    if ($isSharedLogFound) {
        $script:SharedLogMessages = Get-Content $sharedLogPath -Raw | ConvertFrom-Json
    }
}

function Show-ScriptHelp {
    param(
        [string]$Name,
        [string]$Version,
        [string]$Description,
        [hashtable[]]$Commands = @(),
        [string[]]$Examples = @(),
        [hashtable[]]$Flags = @(),
        [PSObject]$LogMessages
    )

    $slm = $script:SharedLogMessages

    # New-style: extract from LogMessages object
    if ($LogMessages) {
        $isNameMissing        = -not $Name -and $LogMessages.scriptName
        $isDescriptionMissing = -not $Description -and $LogMessages.description
        if ($isNameMissing)        { $Name = $LogMessages.scriptName }
        if ($isDescriptionMissing) { $Description = $LogMessages.description }

        # Extract commands from log messages help block
        if ($Commands.Count -eq 0 -and $LogMessages.help -and $LogMessages.help.commands) {
            foreach ($prop in $LogMessages.help.commands.PSObject.Properties) {
                $Commands += @{ Name = $prop.Name; Description = $prop.Value }
            }
        }

        # Extract parameters from log messages help block
        if ($Flags.Count -eq 0 -and $LogMessages.help -and $LogMessages.help.parameters) {
            foreach ($prop in $LogMessages.help.parameters.PSObject.Properties) {
                $Flags += @{ Name = $prop.Name; Description = $prop.Value }
            }
        }

        # Auto-inject -Path parameter if not already listed
        $hasPathFlag = $Flags | Where-Object { $_.Name -eq "-Path" }
        $isPathMissing = -not $hasPathFlag
        if ($isPathMissing) {
            $Flags += @{ Name = "-Path"; Description = "Custom dev directory path (overrides smart detection)" }
        }

        # Extract examples
        if ($Examples.Count -eq 0 -and $LogMessages.help -and $LogMessages.help.examples) {
            $Examples = @($LogMessages.help.examples)
        }
    }

    Write-Host ""
    $headerLine = $slm.messages.helpHeader -replace '\{name\}', $Name -replace '\{version\}', $Version
    Write-Host $headerLine -ForegroundColor Cyan
    $descLine = $slm.messages.helpDescription -replace '\{description\}', $Description
    Write-Host $descLine -ForegroundColor Gray

    # -- Version detection (versionDetect array in log-messages.json) ----------
    $hasVersionDetect = $LogMessages -and $LogMessages.PSObject.Properties.Name -contains "versionDetect"
    if ($hasVersionDetect) {
        Write-Host ""
        foreach ($probe in $LogMessages.versionDetect) {
            $probeCmd  = $probe.command
            $probeFlag = if ($probe.PSObject.Properties.Name -contains "flag") { $probe.flag } else { "--version" }
            $probeLabel = if ($probe.PSObject.Properties.Name -contains "label") { $probe.label } else { $probeCmd }

            $cmdInfo = Get-Command $probeCmd -ErrorAction SilentlyContinue
            $isCmdFound = $null -ne $cmdInfo
            if ($isCmdFound) {
                $rawVersion = $null
                $flagArgs = $probeFlag -split '\s+'
                try { $rawVersion = & $probeCmd @flagArgs 2>$null } catch {}

                $versionText = "$rawVersion".Trim()
                $hasVersion = -not [string]::IsNullOrWhiteSpace($versionText)
                if ($hasVersion) {
                    Write-Host "    $probeLabel : " -NoNewline -ForegroundColor Gray
                    Write-Host $versionText -ForegroundColor Green
                } else {
                    Write-Host "    $probeLabel : " -NoNewline -ForegroundColor Gray
                    Write-Host "(installed, version unknown)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "    $probeLabel : " -NoNewline -ForegroundColor Gray
                Write-Host "not installed" -ForegroundColor DarkGray
            }
        }
    }

    Write-Host ""

    if ($Commands.Count -gt 0) {
        Write-Host $slm.messages.helpCommandsLabel -ForegroundColor Yellow
        foreach ($cmd in $Commands) {
            $label = "{0,-16}" -f $cmd.Name
            $line = $slm.messages.helpCommandItem -replace '\{label\}', $label -replace '\{description\}', $cmd.Description
            Write-Host $line -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($Flags.Count -gt 0) {
        Write-Host $slm.messages.helpParametersLabel -ForegroundColor Yellow
        foreach ($flag in $Flags) {
            $label = "{0,-16}" -f $flag.Name
            $line = $slm.messages.helpParameterItem -replace '\{label\}', $label -replace '\{description\}', $flag.Description
            Write-Host $line -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($Examples.Count -gt 0) {
        Write-Host $slm.messages.helpExamplesLabel -ForegroundColor Yellow
        foreach ($ex in $Examples) {
            $line = $slm.messages.helpExampleItem -replace '\{example\}', $ex
            Write-Host $line -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}
