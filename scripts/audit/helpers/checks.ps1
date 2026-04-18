# --------------------------------------------------------------------------
#  Audit helper -- individual check functions
# --------------------------------------------------------------------------

$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Write-CheckResult {
    param(
        [string]$CheckName,
        [bool]$Passed,
        [string[]]$Details,
        $LogMessages
    )

    if ($Passed) {
        $msg = $LogMessages.messages.checkPass -replace '\{check\}', $CheckName
        Write-Log $msg -Level "success"
    } else {
        $msg = $LogMessages.messages.checkFail -replace '\{check\}', $CheckName
        Write-Log $msg -Level "error"
        foreach ($d in $Details) {
            $detailMsg = $LogMessages.messages.detail -replace '\{detail\}', $d
            Write-Host "  $detailMsg" -ForegroundColor DarkGray
        }
    }
}

# --------------------------------------------------------------------------
#  Check 1: Registry vs folders
# --------------------------------------------------------------------------
function Test-RegistryVsFolders {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $scriptsDir = Join-Path $RepoRoot "scripts"

    # Every registry entry must have a matching folder
    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $id = $prop.Name
        $folder = $prop.Value
        $folderPath = Join-Path $scriptsDir $folder
        $isMissing = -not (Test-Path $folderPath)
        if ($isMissing) {
            $issues += "Registry ID '$id' maps to '$folder' but folder does not exist"
        }
    }

    # Every numbered folder must be in the registry
    $numberedFolders = Get-ChildItem -Path $scriptsDir -Directory | Where-Object { $_.Name -match '^\d{2}-' }
    foreach ($dir in $numberedFolders) {
        $prefix = $dir.Name.Substring(0, 2)
        $isInRegistry = $null -ne $Registry.scripts.$prefix
        if (-not $isInRegistry) {
            $issues += "Folder '$($dir.Name)' (prefix $prefix) not found in registry.json"
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Registry vs folders" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 2: Orchestrator config vs registry
# --------------------------------------------------------------------------
function Test-OrchestratorConfig {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $configPath = Join-Path $RepoRoot "scripts\12-install-all-dev-tools\config.json"
    $isConfigMissing = -not (Test-Path $configPath)
    if ($isConfigMissing) {
        $issues += "Orchestrator config.json not found"
        Write-CheckResult -CheckName "Orchestrator config vs registry" -Passed $false -Details $issues -LogMessages $LogMessages
        return @{ Passed = $false; Issues = $issues }
    }

    $orchConfig = Get-Content $configPath -Raw | ConvertFrom-Json

    # Check sequence IDs
    foreach ($id in $orchConfig.sequence) {
        $isInRegistry = $null -ne $Registry.scripts.$id
        if (-not $isInRegistry) {
            $issues += "Sequence ID '$id' not found in registry.json"
        }
    }

    # Check scripts block IDs
    foreach ($prop in $orchConfig.scripts.PSObject.Properties) {
        $id = $prop.Name
        $isInRegistry = $null -ne $Registry.scripts.$id
        if (-not $isInRegistry) {
            $issues += "Scripts block ID '$id' not found in registry.json"
        }
        # Also verify folder matches registry
        if ($isInRegistry) {
            $registryFolder = $Registry.scripts.$id
            $configFolder = $prop.Value.folder
            $isMismatch = $registryFolder -ne $configFolder
            if ($isMismatch) {
                $issues += "ID '$id': registry says '$registryFolder' but orchestrator config says '$configFolder'"
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Orchestrator config vs registry" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 3: Orchestrator groups vs scripts
# --------------------------------------------------------------------------
function Test-OrchestratorGroups {
    param(
        [string]$RepoRoot,
        $LogMessages
    )

    $issues = @()
    $configPath = Join-Path $RepoRoot "scripts\12-install-all-dev-tools\config.json"
    $isConfigMissing = -not (Test-Path $configPath)
    if ($isConfigMissing) {
        $issues += "Orchestrator config.json not found"
        Write-CheckResult -CheckName "Orchestrator groups vs scripts" -Passed $false -Details $issues -LogMessages $LogMessages
        return @{ Passed = $false; Issues = $issues }
    }

    $orchConfig = Get-Content $configPath -Raw | ConvertFrom-Json
    $hasGroups = $null -ne $orchConfig.groups

    if ($hasGroups) {
        foreach ($group in $orchConfig.groups) {
            foreach ($gid in $group.ids) {
                $isInScripts = $null -ne $orchConfig.scripts.$gid
                if (-not $isInScripts) {
                    $issues += "Group '$($group.label)' references ID '$gid' not found in scripts block"
                }
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Orchestrator groups vs scripts" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 4: Spec folder coverage
# --------------------------------------------------------------------------
function Test-SpecCoverage {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $specDir = Join-Path $RepoRoot "spec"

    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $id = $prop.Name
        $folder = $prop.Value
        $specPath = Join-Path $specDir "$folder\readme.md"
        $isMissing = -not (Test-Path $specPath)
        if ($isMissing) {
            $issues += "No spec found for ID '$id' (expected spec/$folder/readme.md)"
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Spec folder coverage" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 5: Config + log-messages existence
# --------------------------------------------------------------------------
function Test-ConfigLogMessages {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $scriptsDir = Join-Path $RepoRoot "scripts"

    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $id = $prop.Name
        $folder = $prop.Value
        $folderPath = Join-Path $scriptsDir $folder
        $isFolderMissing = -not (Test-Path $folderPath)
        if ($isFolderMissing) { continue }

        $configPath = Join-Path $folderPath "config.json"
        $logMsgPath = Join-Path $folderPath "log-messages.json"

        $isConfigMissing = -not (Test-Path $configPath)
        $isLogMsgMissing = -not (Test-Path $logMsgPath)

        if ($isConfigMissing) {
            $issues += "ID '$id' ($folder): missing config.json"
        }
        if ($isLogMsgMissing) {
            $issues += "ID '$id' ($folder): missing log-messages.json"
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Config + log-messages existence" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 6 & 7: Stale ID references in markdown files
# --------------------------------------------------------------------------
function Test-StaleRefsInMarkdown {
    param(
        [string]$SearchDir,
        [string]$CheckName,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $isSearchDirMissing = -not (Test-Path $SearchDir)
    if ($isSearchDirMissing) {
        Write-CheckResult -CheckName $CheckName -Passed $true -Details @() -LogMessages $LogMessages
        return @{ Passed = $true; Issues = @() }
    }

    # Build set of valid IDs and folder names
    $validIds = @()
    $validFolders = @()
    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $validIds += $prop.Name
        $validFolders += $prop.Value
    }

    $mdFiles = Get-ChildItem -Path $SearchDir -Filter "*.md" -Recurse
    foreach ($file in $mdFiles) {
        $content = Get-Content $file.FullName -Raw

        # Look for "Script NN" references
        $scriptRefs = [regex]::Matches($content, 'Script\s+(\d{2})')
        foreach ($match in $scriptRefs) {
            $refId = $match.Groups[1].Value
            $isValid = $refId -in $validIds
            if (-not $isValid) {
                $issues += "$($file.Name): references 'Script $refId' but no such ID in registry"
            }
        }

        # Look for "scripts/NN-" folder references
        $folderRefs = [regex]::Matches($content, 'scripts/(\d{2}-[a-zA-Z0-9-]+)')
        foreach ($match in $folderRefs) {
            $refFolder = $match.Groups[1].Value
            $isValid = $refFolder -in $validFolders
            if (-not $isValid) {
                $issues += "$($file.Name): references folder '$refFolder' not found in registry"
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName $CheckName -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 8: Stale ID references in PowerShell files
# --------------------------------------------------------------------------
function Test-StaleRefsInPowerShell {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $scriptsDir = Join-Path $RepoRoot "scripts"

    # Build valid folder names
    $validFolders = @()
    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $validFolders += $prop.Value
    }

    $ps1Files = Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -Recurse
    foreach ($file in $ps1Files) {
        $content = Get-Content $file.FullName -Raw

        # Look for hardcoded folder references like "01-install-vscode"
        $folderRefs = [regex]::Matches($content, '(\d{2}-[a-zA-Z0-9]+-[a-zA-Z0-9-]+)')
        foreach ($match in $folderRefs) {
            $refFolder = $match.Groups[1].Value
            # Skip if it matches a valid folder
            $isValid = $refFolder -in $validFolders
            # Skip common false positives (dates, version strings, etc.)
            $isFalsePositive = $refFolder -match '^\d{2}-\d{2}' -or $refFolder -match 'yyyyMMdd'
            if (-not $isValid -and -not $isFalsePositive) {
                $relativePath = $file.FullName.Replace($RepoRoot, '').TrimStart('\', '/')
                $issues += "${relativePath}: references folder '$refFolder' not found in registry"
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Stale refs in PowerShell" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 10: Keyword modes vs config.json validModes
# --------------------------------------------------------------------------
function Test-KeywordModes {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $keywordsPath = Join-Path $RepoRoot "scripts\shared\install-keywords.json"
    $isKeywordsMissing = -not (Test-Path $keywordsPath)
    if ($isKeywordsMissing) {
        $issues += "install-keywords.json not found"
        Write-CheckResult -CheckName "Keyword modes vs config validModes" -Passed $false -Details $issues -LogMessages $LogMessages
        return @{ Passed = $false; Issues = $issues }
    }

    $keywords = Get-Content $keywordsPath -Raw | ConvertFrom-Json
    $hasModes = $null -ne $keywords.modes

    if (-not $hasModes) {
        Write-CheckResult -CheckName "Keyword modes vs config validModes" -Passed $true -Details @() -LogMessages $LogMessages
        return @{ Passed = $true; Issues = @() }
    }

    # Build a map of scriptId -> validModes from each script's config.json
    $validModesMap = @{}
    $scriptsDir = Join-Path $RepoRoot "scripts"

    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $id = $prop.Name
        $folder = $prop.Value
        $configPath = Join-Path $scriptsDir "$folder\config.json"
        $isConfigPresent = Test-Path $configPath
        if ($isConfigPresent) {
            $scriptConfig = Get-Content $configPath -Raw | ConvertFrom-Json
            $hasValidModes = ($scriptConfig.PSObject.Properties.Name -contains 'validModes')
            if ($hasValidModes) {
                $validModesMap[$id] = @($scriptConfig.validModes)
            } else {
                # Check nested config objects for validModes
                foreach ($nested in $scriptConfig.PSObject.Properties) {
                    $isObject = $nested.Value -is [PSCustomObject]
                    if ($isObject) {
                        $hasNestedModes = ($nested.Value.PSObject.Properties.Name -contains 'validModes')
                        if ($hasNestedModes) {
                            $validModesMap[$id] = @($nested.Value.validModes)
                            break
                        }
                    }
                }
            }
        }
    }

    # Validate each mode entry in keywords.modes
    foreach ($prop in $keywords.modes.PSObject.Properties) {
        $keyword = $prop.Name
        $modeMap = $prop.Value

        foreach ($modeProp in $modeMap.PSObject.Properties) {
            $scriptId = $modeProp.Name
            $modeValue = $modeProp.Value
            $paddedId = $scriptId.PadLeft(2, '0')

            # Check script exists in registry
            $isInRegistry = $null -ne $Registry.scripts.$paddedId
            if (-not $isInRegistry) {
                $issues += "Keyword '$keyword': references script ID '$scriptId' not in registry"
                continue
            }

            # Check mode value against validModes
            $hasValidModes = $validModesMap.ContainsKey($paddedId)
            if ($hasValidModes) {
                $isValidMode = $modeValue -in $validModesMap[$paddedId]
                if (-not $isValidMode) {
                    $folder = $Registry.scripts.$paddedId
                    $allowed = $validModesMap[$paddedId] -join ', '
                    $issues += "Keyword '$keyword': mode '$modeValue' not in $folder/config.json validModes [$allowed]"
                }
            } else {
                $folder = $Registry.scripts.$paddedId
                $issues += "Keyword '$keyword': script '$folder' has no validModes in config.json"
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Keyword modes vs config validModes" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 9: Verify database symlinks
# --------------------------------------------------------------------------
function Test-VerifySymlinks {
    param(
        [string]$RepoRoot,
        $LogMessages,
        [switch]$Fix,
        [switch]$DryRun
    )

    $issues = @()
    $details = @()

    # Resolve dev dir from databases config
    $dbConfigPath = Join-Path $RepoRoot "scripts\databases\config.json"
    $isDbConfigMissing = -not (Test-Path $dbConfigPath)
    if ($isDbConfigMissing) {
        $issues += "databases/config.json not found -- cannot determine dev directory"
        Write-CheckResult -CheckName "Verify database symlinks" -Passed $false -Details $issues -LogMessages $LogMessages
        return @{ Passed = $false; Issues = $issues }
    }

    $dbConfig = Get-Content $dbConfigPath -Raw | ConvertFrom-Json

    # Find the databases directory using smart drive detection or env
    $devDir = $null
    $hasDevDirEnv = -not [string]::IsNullOrWhiteSpace($env:DEV_DIR)
    if ($hasDevDirEnv) {
        $devDir = $env:DEV_DIR
    } else {
        # Check preferred drives in order: E, D, then scan others
        foreach ($letter in @("E", "D")) {
            $testPath = "${letter}:\dev-tool\databases"
            $isPresent = Test-Path $testPath
            if ($isPresent) {
                $devDir = "${letter}:\dev-tool"
                break
            }
        }
        # If not found on E/D, scan other fixed drives
        $hasNoDevDir = $null -eq $devDir
        if ($hasNoDevDir) {
            $fixedDisks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
            foreach ($disk in $fixedDisks) {
                $letter = $disk.DeviceID.Substring(0, 1)
                $isAlreadyChecked = $letter -eq "E" -or $letter -eq "D"
                if ($isAlreadyChecked) { continue }
                $testPath = "${letter}:\dev-tool\databases"
                $isPresent = Test-Path $testPath
                if ($isPresent) {
                    $devDir = "${letter}:\dev-tool"
                    break
                }
            }
        }
    }

    $hasNoDevDir = $null -eq $devDir
    if ($hasNoDevDir) {
        $details += "No dev\databases\ directory found on any drive -- no symlinks to verify"
        Write-CheckResult -CheckName "Verify database symlinks" -Passed $true -Details $details -LogMessages $LogMessages
        return @{ Passed = $true; Issues = @() }
    }

    $dbDir = Join-Path $devDir "databases"
    $isDbDirMissing = -not (Test-Path $dbDir)
    if ($isDbDirMissing) {
        $details += "databases directory not found at $dbDir -- no symlinks to verify"
        Write-CheckResult -CheckName "Verify database symlinks" -Passed $true -Details $details -LogMessages $LogMessages
        return @{ Passed = $true; Issues = @() }
    }

    Write-Host ""
    Write-Host "  Scanning: $dbDir" -ForegroundColor Cyan
    Write-Host ""

    # Get expected databases from config (with verifyCommand for --fix)
    $expectedDbs = @()
    foreach ($prop in $dbConfig.databases.PSObject.Properties) {
        $db = $prop.Value
        $isEnabled = $db.enabled -eq $true
        if ($isEnabled) {
            $expectedDbs += [PSCustomObject]@{
                Key           = $prop.Name
                Name          = $db.name
                Package       = if ($db.chocoPackage) { $db.chocoPackage } elseif ($db.dotnetPackage) { $db.dotnetPackage } else { $prop.Name }
                VerifyCommand = if ($db.verifyCommand) { $db.verifyCommand } else { $null }
            }
        }
    }

    # Scan existing items in the databases directory
    $items = Get-ChildItem -Path $dbDir -ErrorAction SilentlyContinue
    $foundJunctions  = @()
    $brokenJunctions = @()
    $realDirs        = @()

    foreach ($item in $items) {
        $isJunction = $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint
        if ($isJunction) {
            $target = $item.Target
            $isTargetValid = $null -ne $target -and (Test-Path $target)
            if ($isTargetValid) {
                $foundJunctions += [PSCustomObject]@{ Name = $item.Name; Target = $target }
                Write-Host "    [LINK]   $($item.Name)" -ForegroundColor Green -NoNewline
                Write-Host " -> $target" -ForegroundColor DarkGray
            } else {
                $brokenJunctions += [PSCustomObject]@{ Name = $item.Name; Target = $target; Path = $item.FullName }
                Write-Host "    [BROKEN] $($item.Name)" -ForegroundColor Red -NoNewline
                Write-Host " -> $target (target missing)" -ForegroundColor DarkGray
                $issues += "Broken junction: $($item.Name) -> $target"
            }
        } else {
            $realDirs += $item.Name
            Write-Host "    [DIR]    $($item.Name)" -ForegroundColor Yellow -NoNewline
            Write-Host " (real directory, not a junction)" -ForegroundColor DarkGray
        }
    }

    # Check for expected databases with no junction
    $missingLinks = @()
    foreach ($db in $expectedDbs) {
        $packageName = $db.Package
        $isFound = ($foundJunctions | Where-Object { $_.Name -eq $packageName }).Count -gt 0
        $isRealDir = $packageName -in $realDirs
        $isBroken = ($brokenJunctions | Where-Object { $_.Name -eq $packageName }).Count -gt 0
        $hasNoEntry = -not $isFound -and -not $isRealDir -and -not $isBroken
        if ($hasNoEntry) {
            $missingLinks += $db
        }
    }

    # -- DryRun mode: preview what --Fix would do --------------------------------
    $isDryRunMode = $DryRun -and -not $Fix
    if ($isDryRunMode) {
        Write-Host ""
        Write-Host "    --- Dry Run Preview ---" -ForegroundColor Magenta

        $hasNothingToFix = $brokenJunctions.Count -eq 0 -and $missingLinks.Count -eq 0
        if ($hasNothingToFix) {
            Write-Host "    Nothing to fix -- all symlinks are healthy" -ForegroundColor Green
        }

        foreach ($broken in $brokenJunctions) {
            $db = $expectedDbs | Where-Object { $_.Package -eq $broken.Name } | Select-Object -First 1
            $hasVerifyCmd = $null -ne $db -and -not [string]::IsNullOrWhiteSpace($db.VerifyCommand)
            if ($hasVerifyCmd) {
                Write-Host "    [WOULD REMOVE]  $($broken.Name) (broken -> $($broken.Target))" -ForegroundColor Yellow
                Write-Host "    [WOULD CREATE]  $($broken.Name) -> (resolved via $($db.VerifyCommand))" -ForegroundColor Cyan
            } else {
                Write-Host "    [WOULD SKIP]    $($broken.Name) -- no verify command in config" -ForegroundColor DarkGray
            }
        }

        foreach ($db in $missingLinks) {
            $hasVerifyCmd = -not [string]::IsNullOrWhiteSpace($db.VerifyCommand)
            if ($hasVerifyCmd) {
                $cmd = Get-Command $db.VerifyCommand -ErrorAction SilentlyContinue
                $isInstalled = $null -ne $cmd
                if ($isInstalled) {
                    Write-Host "    [WOULD CREATE]  $($db.Package) -> (resolved via $($db.VerifyCommand))" -ForegroundColor Cyan
                } else {
                    Write-Host "    [WOULD SKIP]    $($db.Name) -- not installed" -ForegroundColor DarkGray
                }
            }
        }

        Write-Host ""
    }

    # -- Fix mode: repair broken junctions and create missing ones -------------
    $fixedCount = 0
    if ($Fix) {
        Write-Host ""

        # Fix broken junctions: remove and recreate
        foreach ($broken in $brokenJunctions) {
            $db = $expectedDbs | Where-Object { $_.Package -eq $broken.Name } | Select-Object -First 1
            $hasVerifyCmd = $null -ne $db -and -not [string]::IsNullOrWhiteSpace($db.VerifyCommand)
            if ($hasVerifyCmd) {
                Write-Host "    [FIX]    Removing broken junction: $($broken.Name)..." -ForegroundColor Cyan
                Remove-Item $broken.Path -Force -ErrorAction SilentlyContinue
                $isFixed = New-DbSymlink -Name $broken.Name -VerifyCommand $db.VerifyCommand -DevDir $devDir
                if ($isFixed) {
                    $fixedCount++
                    # Remove from issues since it's now fixed
                    $issues = @($issues | Where-Object { $_ -notmatch [regex]::Escape($broken.Name) })
                }
            } else {
                Write-Host "    [SKIP]   Cannot fix $($broken.Name) -- no verify command found in config" -ForegroundColor DarkGray
            }
        }

        # Fix missing symlinks: create them
        foreach ($db in $missingLinks) {
            $hasVerifyCmd = -not [string]::IsNullOrWhiteSpace($db.VerifyCommand)
            if ($hasVerifyCmd) {
                $cmd = Get-Command $db.VerifyCommand -ErrorAction SilentlyContinue
                $isInstalled = $null -ne $cmd
                if ($isInstalled) {
                    Write-Host "    [FIX]    Creating missing symlink: $($db.Package)..." -ForegroundColor Cyan
                    $isCreated = New-DbSymlink -Name $db.Package -VerifyCommand $db.VerifyCommand -DevDir $devDir
                    if ($isCreated) { $fixedCount++ }
                } else {
                    Write-Host "    [SKIP]   $($db.Name) not installed -- cannot create symlink" -ForegroundColor DarkGray
                }
            }
        }

        $hasFixed = $fixedCount -gt 0
        if ($hasFixed) {
            Write-Host ""
            Write-Host "    Fixed:   $fixedCount symlink(s)" -ForegroundColor Green
        }
    }

    Write-Host ""

    # Summary stats
    $totalExpected = $expectedDbs.Count
    $linkedCount   = $foundJunctions.Count + $fixedCount
    $brokenCount   = ($issues | Where-Object { $_ -match "^Broken junction" }).Count
    $realCount     = $realDirs.Count
    $missingCount  = ($missingLinks | Where-Object {
        $pkg = $_.Package
        -not ($Fix -and ($fixedCount -gt 0))
    }).Count

    Write-Host "    Linked:  $linkedCount / $totalExpected" -ForegroundColor $(if ($linkedCount -eq $totalExpected) { "Green" } else { "Yellow" })

    $hasBroken = $brokenCount -gt 0
    if ($hasBroken) {
        Write-Host "    Broken:  $brokenCount" -ForegroundColor Red
    }

    $hasReal = $realCount -gt 0
    if ($hasReal) {
        Write-Host "    Real:    $realCount (not junctions)" -ForegroundColor Yellow
    }

    $hasMissing = $missingCount -gt 0
    $isNotFixMode = -not $Fix
    if ($hasMissing -and $isNotFixMode) {
        Write-Host "    Missing: $missingCount" -ForegroundColor DarkGray
        foreach ($db in $missingLinks) {
            Write-Host "             - $($db.Name) ($($db.Package))" -ForegroundColor DarkGray
        }
    }

    # Broken junctions are failures; missing/real are warnings only
    $isPassed = $brokenCount -eq 0
    Write-CheckResult -CheckName "Verify database symlinks" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 11: Uninstall coverage
# --------------------------------------------------------------------------
function Test-UninstallCoverage {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $scriptsDir = Join-Path $RepoRoot "scripts"

    # Scripts exempt from uninstall requirement
    # 02 = Chocolatey (would break uninstall chain)
    # 12 = orchestrator (batch uninstall, not individual)
    # audit = audit script (no tool to uninstall)
    # databases = orchestrator (batch uninstall, not individual)
    $exemptFolders = @(
        "02-install-package-managers",
        "12-install-all-dev-tools",
        "audit",
        "databases"
    )

    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $id = $prop.Name
        $folder = $prop.Value
        $isExempt = $folder -in $exemptFolders
        if ($isExempt) { continue }

        $folderPath = Join-Path $scriptsDir $folder
        $isFolderMissing = -not (Test-Path $folderPath)
        if ($isFolderMissing) { continue }

        # -- Check 1: Helper file has Uninstall-* function --
        $helpersDir = Join-Path $folderPath "helpers"
        $hasHelpersDir = Test-Path $helpersDir
        $hasUninstallFunc = $false
        if ($hasHelpersDir) {
            $helperFiles = Get-ChildItem -Path $helpersDir -Filter "*.ps1" -ErrorAction SilentlyContinue
            foreach ($helperFile in $helperFiles) {
                $content = Get-Content $helperFile.FullName -Raw
                $isUninstallPresent = $content -match 'function\s+Uninstall-'
                if ($isUninstallPresent) {
                    $hasUninstallFunc = $true
                    break
                }
            }
        }
        if (-not $hasUninstallFunc) {
            $issues += "ID '$id' ($folder): no Uninstall-* function found in helpers/"
        }

        # -- Check 2: run.ps1 has 'uninstall' command handler --
        $runFile = Join-Path $folderPath "run.ps1"
        $isRunPresent = Test-Path $runFile
        if ($isRunPresent) {
            $runContent = Get-Content $runFile -Raw
            $hasUninstallCommand = $runContent -match '[''"]uninstall[''"]'
            if (-not $hasUninstallCommand) {
                $issues += "ID '$id' ($folder): run.ps1 missing 'uninstall' command handler"
            }
        }

        # -- Check 3: log-messages.json has uninstall help entry --
        $logMsgPath = Join-Path $folderPath "log-messages.json"
        $isLogMsgPresent = Test-Path $logMsgPath
        if ($isLogMsgPresent) {
            $logMsgContent = Get-Content $logMsgPath -Raw
            $hasUninstallHelp = $logMsgContent -match '[Uu]ninstall'
            if (-not $hasUninstallHelp) {
                $issues += "ID '$id' ($folder): log-messages.json missing uninstall help entry"
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Uninstall coverage" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 12: Export coverage (settings-capable scripts)
# --------------------------------------------------------------------------
function Test-ExportCoverage {
    param(
        [string]$RepoRoot,
        $Registry,
        [string[]]$ExportCapableIds,
        $LogMessages
    )

    $issues = @()
    $scriptsDir = Join-Path $RepoRoot "scripts"

    foreach ($id in $ExportCapableIds) {
        $folder = $Registry.scripts.$id
        $isIdMissing = $null -eq $folder
        if ($isIdMissing) {
            $issues += "Export-capable ID '$id' not found in registry"
            continue
        }

        $folderPath = Join-Path $scriptsDir $folder
        $isFolderMissing = -not (Test-Path $folderPath)
        if ($isFolderMissing) { continue }

        # -- Check 1: Helper file has Export-* function --
        $helpersDir = Join-Path $folderPath "helpers"
        $hasHelpersDir = Test-Path $helpersDir
        $hasExportFunc = $false
        if ($hasHelpersDir) {
            $helperFiles = Get-ChildItem -Path $helpersDir -Filter "*.ps1" -ErrorAction SilentlyContinue
            foreach ($helperFile in $helperFiles) {
                $content = Get-Content $helperFile.FullName -Raw
                $isExportPresent = $content -match 'function\s+Export-'
                if ($isExportPresent) {
                    $hasExportFunc = $true
                    break
                }
            }
        }
        if (-not $hasExportFunc) {
            $issues += "ID '$id' ($folder): no Export-* function found in helpers/"
        }

        # -- Check 2: run.ps1 has 'export' command handler --
        $runFile = Join-Path $folderPath "run.ps1"
        $isRunPresent = Test-Path $runFile
        if ($isRunPresent) {
            $runContent = Get-Content $runFile -Raw
            $hasExportCommand = $runContent -match '[''"]export[''"]'
            if (-not $hasExportCommand) {
                $issues += "ID '$id' ($folder): run.ps1 missing 'export' command handler"
            }
        }

        # -- Check 3: log-messages.json has export-related entry --
        $logMsgPath = Join-Path $folderPath "log-messages.json"
        $isLogMsgPresent = Test-Path $logMsgPath
        if ($isLogMsgPresent) {
            $logMsgContent = Get-Content $logMsgPath -Raw
            $hasExportMsg = $logMsgContent -match '[Ee]xport'
            if (-not $hasExportMsg) {
                $issues += "ID '$id' ($folder): log-messages.json missing export-related messages"
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Export coverage" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}