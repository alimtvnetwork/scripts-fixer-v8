<#
.SYNOPSIS
    Interactive menu for database installer.
#>

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Show-DbMenu {
    <#
    .SYNOPSIS
        Displays the interactive database selection menu and returns
        an array of selected database keys.
    #>
    param(
        $Config,
        $LogMessages
    )

    $sequence = $Config.sequence
    $dbs      = $Config.databases
    $groups   = $Config.groups

    # Build items list
    $items = @()
    $index = 1
    foreach ($key in $sequence) {
        $entry = $dbs.$key
        $hasNoEntry = -not $entry
        if ($hasNoEntry) { continue }

        $items += @{
            Index    = $index
            Key      = $key
            Name     = $entry.name
            Desc     = $entry.desc
            Type     = $entry.type
            Selected = $false
        }
        $index++
    }

    while ($true) {
        Write-Host ""
        Write-Host "  $($LogMessages.messages.menuTitle)" -ForegroundColor Cyan
        Write-Host "  $($LogMessages.messages.menuSeparator)" -ForegroundColor DarkGray
        Write-Host ""

        # Group by type for display
        $types = [ordered]@{
            "sql"             = "Relational (SQL)"
            "nosql-document"  = "NoSQL -- Document"
            "nosql-keyvalue"  = "NoSQL -- Key-Value"
            "nosql-column"    = "NoSQL -- Column"
            "nosql-graph"     = "NoSQL -- Graph"
            "search"          = "Search Engine"
            "file-based"      = "File-Based / Embedded"
        }

        foreach ($typeKey in $types.Keys) {
            $typeItems = $items | Where-Object { $_.Type -eq $typeKey }
            $hasItems = $typeItems.Count -gt 0
            if ($hasItems) {
                Write-Host "    $($types[$typeKey])" -ForegroundColor Magenta
                foreach ($item in $typeItems) {
                    $check = if ($item.Selected) { "[X]" } else { "[ ]" }
                    $num = "$($item.Index).".PadRight(4)
                    $nameCol = $item.Name.PadRight(24)
                    Write-Host "    $check $num$nameCol" -NoNewline
                    Write-Host $item.Desc -ForegroundColor DarkGray
                }
                Write-Host ""
            }
        }

        # Show groups
        Write-Host "  $($LogMessages.messages.menuGroupsLabel)" -ForegroundColor Yellow
        $groupCol = 48
        for ($gi = 0; $gi -lt $groups.Count; $gi += 2) {
            $left = "    $($groups[$gi].letter). $($groups[$gi].label)"
            $hasRight = ($gi + 1) -lt $groups.Count
            if ($hasRight) {
                $right = "$($groups[$gi+1].letter). $($groups[$gi+1].label)"
                Write-Host "$($left.PadRight($groupCol))$right"
            } else {
                Write-Host $left
            }
        }

        Write-Host ""
        Write-Host "  $($LogMessages.messages.menuPrompt)" -ForegroundColor Yellow
        $input = Read-Host "  "

        $isQuit = $input -eq "Q" -or $input -eq "q"
        if ($isQuit) {
            Write-Log $LogMessages.messages.menuInputQuit -Level "info"
            return @()
        }

        $isEnter = [string]::IsNullOrWhiteSpace($input)
        if ($isEnter) {
            $selected = $items | Where-Object { $_.Selected } | ForEach-Object { $_.Key }
            $hasNoSelection = $selected.Count -eq 0
            if ($hasNoSelection) {
                Write-Log $LogMessages.messages.menuNoSelection -Level "warn"
                continue
            }
            return $selected
        }

        $isAll = $input -eq "A"
        if ($isAll) {
            foreach ($item in $items) { $item.Selected = $true }
            Write-Log $LogMessages.messages.menuInputAll -Level "info"
            continue
        }

        $isNone = $input -eq "N"
        if ($isNone) {
            foreach ($item in $items) { $item.Selected = $false }
            Write-Log $LogMessages.messages.menuInputNone -Level "info"
            continue
        }

        # Check for group letter
        $matchedGroup = $groups | Where-Object { $_.letter -eq $input.ToLower() }
        $isGroupMatch = [bool]$matchedGroup
        if ($isGroupMatch) {
            foreach ($item in $items) { $item.Selected = $false }
            foreach ($id in $matchedGroup.ids) {
                $target = $items | Where-Object { $_.Key -eq $id }
                if ($target) { $target.Selected = $true }
            }
            Write-Log ($LogMessages.messages.menuInputGroup -replace '\{group\}', $matchedGroup.label) -Level "info"
            continue
        }

        # Parse numbers (CSV or space-separated)
        $tokens = $input -replace ',', ' ' -split '\s+' | Where-Object { $_.Length -gt 0 }
        foreach ($token in $tokens) {
            $isNumeric = $token -match '^\d+$'
            if ($isNumeric) {
                $num = [int]$token
                $target = $items | Where-Object { $_.Index -eq $num }
                if ($target) {
                    $target.Selected = -not $target.Selected
                    Write-Log ($LogMessages.messages.menuInputToggle -replace '\{name\}', $target.Name) -Level "info"
                }
            }
        }
    }
}

function Get-InstallPath {
    <#
    .SYNOPSIS
        Prompts user for install location: devDir, custom, or system default.
        Returns the resolved path or empty string for system default.
    #>
    param(
        [string]$DevDir,
        $LogMessages
    )

    Write-Host ""
    Write-Host "  $($LogMessages.messages.installPathTitle)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    [1] " -NoNewline -ForegroundColor Cyan
    Write-Host ($LogMessages.messages.installPathDevDir -replace '\{path\}', $DevDir)
    Write-Host "    [2] " -NoNewline -ForegroundColor Cyan
    Write-Host "Custom path (you choose)"
    Write-Host "    [3] " -NoNewline -ForegroundColor Cyan
    Write-Host $LogMessages.messages.installPathSystem
    Write-Host ""

    $choice = Read-Host "  Choose [1/2/3] (default: 1)"

    $isCustom = $choice -eq "2"
    if ($isCustom) {
        $customPath = Read-Host "  $($LogMessages.messages.installPathCustom)"
        $hasCustom = -not [string]::IsNullOrWhiteSpace($customPath)
        if ($hasCustom) {
            $dbPath = Join-Path $customPath "databases"
            Write-Log ($LogMessages.messages.installPathChosen -replace '\{path\}', $dbPath) -Level "info"
            return $dbPath
        }
    }

    $isSystem = $choice -eq "3"
    if ($isSystem) {
        Write-Log ($LogMessages.messages.installPathChosen -replace '\{path\}', "(system default)") -Level "info"
        return ""
    }

    # Default: devDir
    $dbPath = Join-Path $DevDir "databases"
    Write-Log ($LogMessages.messages.installPathChosen -replace '\{path\}', $dbPath) -Level "info"
    return $dbPath
}