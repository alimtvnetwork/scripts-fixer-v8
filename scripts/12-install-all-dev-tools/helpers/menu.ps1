# --------------------------------------------------------------------------
#  Orchestrator helper -- Interactive menu + dry-run display
#  Features: lettered group shortcuts, CSV/space number input,
#  all unchecked by default, loop-back after install.
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

# --------------------------------------------------------------------------
#  Build a lookup from group letter -> list of script IDs
# --------------------------------------------------------------------------
function Build-GroupLookup {
    param($Groups)

    $lookup = @{}
    $hasGroups = $null -ne $Groups
    if ($hasGroups) {
        foreach ($group in $Groups) {
            $letter = $group.letter.ToLower()
            $lookup[$letter] = @{
                Label = $group.label
                Ids   = @($group.ids)
            }
        }
    }
    return $lookup
}

# --------------------------------------------------------------------------
#  Render the menu to the console
# --------------------------------------------------------------------------
function Write-MenuDisplay {
    param(
        [array]$ScriptList,
        [hashtable]$Selected,
        [hashtable]$GroupLookup,
        $LogMessages
    )

    Write-Host ""
    Write-Host "  $($LogMessages.messages.menuTitle)" -ForegroundColor Cyan
    Write-Host "  $('=' * $LogMessages.messages.menuTitle.Length)" -ForegroundColor DarkGray
    Write-Host ""

    # Script list
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        $check = if ($Selected[$i]) { "x" } else { " " }
        $num   = "{0,-3}" -f ($i + 1)
        $name  = $ScriptList[$i].Name.PadRight(28)
        $desc  = $ScriptList[$i].Desc

        Write-Host "  [" -NoNewline
        if ($Selected[$i]) {
            Write-Host $check -ForegroundColor Green -NoNewline
        } else {
            Write-Host $check -NoNewline
        }
        Write-Host "] " -NoNewline
        Write-Host "$num " -ForegroundColor Yellow -NoNewline
        Write-Host "$name " -NoNewline
        Write-Host $desc -ForegroundColor DarkGray
    }

    # Group shortcuts
    $hasGroupShortcuts = $GroupLookup.Count -gt 0
    if ($hasGroupShortcuts) {
        # Build ID -> Name lookup from script list
        $nameLookup = @{}
        foreach ($s in $ScriptList) {
            $nameLookup[$s.Id] = $s.Name
        }

        Write-Host ""
        Write-Host "  $($LogMessages.messages.menuGroupsLabel)" -ForegroundColor Yellow

        $sortedKeys = $GroupLookup.Keys | Sort-Object
        foreach ($letter in $sortedKeys) {
            $group = $GroupLookup[$letter]
            $namedIds = ($group.Ids | ForEach-Object {
                $name = $nameLookup[$_]
                if ($name) { "$_-$name" } else { $_ }
            }) -join ", "
            Write-Host "    $letter. " -ForegroundColor Magenta -NoNewline
            Write-Host "$($group.Label)" -NoNewline
            Write-Host " ($namedIds)" -ForegroundColor DarkGray
        }
    }
}

# --------------------------------------------------------------------------
#  Parse user input and update selection state
#  Returns: "run" | "quit" | "continue"
# --------------------------------------------------------------------------
function Update-Selection {
    param(
        [string]$UserInput,
        [array]$ScriptList,
        [hashtable]$Selected,
        [hashtable]$GroupLookup
    )

    $isEnterPressed = [string]::IsNullOrWhiteSpace($UserInput)
    if ($isEnterPressed) { return "run" }

    $trimmed = $UserInput.Trim()
    $upper   = $trimmed.ToUpper()

    # Q = quit
    $isQuit = $upper -eq "Q"
    if ($isQuit) { return "quit" }

    # A = select all
    $isSelectAll = $upper -eq "A"
    if ($isSelectAll) {
        for ($i = 0; $i -lt $ScriptList.Count; $i++) { $Selected[$i] = $true }
        return "continue"
    }

    # N = deselect all
    $isSelectNone = $upper -eq "N"
    if ($isSelectNone) {
        for ($i = 0; $i -lt $ScriptList.Count; $i++) { $Selected[$i] = $false }
        return "continue"
    }

    # Check if it's a group letter
    $lowerInput = $trimmed.ToLower()
    $isGroupLetter = $GroupLookup.ContainsKey($lowerInput)
    if ($isGroupLetter) {
        $groupIds = $GroupLookup[$lowerInput].Ids
        for ($i = 0; $i -lt $ScriptList.Count; $i++) {
            $isInGroup = $ScriptList[$i].Id -in $groupIds
            if ($isInGroup) {
                $Selected[$i] = $true
            }
        }
        return "continue"
    }

    # Parse numbers: support CSV (1,2,5) and space-separated (1 2 5) and mixed
    $tokens = $trimmed -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    foreach ($token in $tokens) {
        $isValidNumber = $token -match '^\d+$'
        if ($isValidNumber) {
            $idx = [int]$token - 1
            $isInRange = $idx -ge 0 -and $idx -lt $ScriptList.Count
            if ($isInRange) {
                $Selected[$idx] = -not $Selected[$idx]
            }
        }
    }
    return "continue"
}

# --------------------------------------------------------------------------
#  Collect selected scripts into an array
# --------------------------------------------------------------------------
function Get-SelectedScripts {
    param(
        [array]$ScriptList,
        [hashtable]$Selected
    )

    $result = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        $isSelected = $Selected[$i]
        if ($isSelected) {
            [void]$result.Add($ScriptList[$i])
        }
    }
    return ,@($result)
}

# --------------------------------------------------------------------------
#  Main interactive menu -- returns "quit" or selected scripts per round
#  Called in a loop by run.ps1
# --------------------------------------------------------------------------
function Show-InteractiveMenu {
    param(
        $ScriptList,
        $LogMessages,
        $Groups
    )

    # Normalize input
    $ScriptList = if ($ScriptList -is [hashtable]) { ,@($ScriptList) } else { @($ScriptList) }

    $groupLookup = Build-GroupLookup -Groups $Groups

    # All unchecked by default
    $selected = @{}
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        $selected[$i] = $false
    }

    while ($true) {
        Write-MenuDisplay -ScriptList $ScriptList -Selected $selected -GroupLookup $groupLookup -LogMessages $LogMessages

        Write-Host ""
        Write-Host "  " -NoNewline
        $userInput = Read-Host $LogMessages.messages.menuPrompt

        $action = Update-Selection -UserInput $userInput -ScriptList $ScriptList -Selected $selected -GroupLookup $groupLookup

        $isQuit = $action -eq "quit"
        if ($isQuit) { return $null }

        $isRun = $action -eq "run"
        if ($isRun) {
            $result = Get-SelectedScripts -ScriptList $ScriptList -Selected $selected
            return ,$result
        }

        # action is "continue" -- loop back to redraw menu
    }
}

# --------------------------------------------------------------------------
#  Dry run display
# --------------------------------------------------------------------------
function Show-DryRun {
    param(
        [array]$ScriptList,
        $LogMessages
    )

    Write-Host ""
    Write-Log $LogMessages.messages.dryRunBanner -Level "warn"
    Write-Host ""

    foreach ($script in $ScriptList) {
        $isDisabled = -not $script.Enabled
        if ($isDisabled) {
            $msg = $LogMessages.messages.dryRunSkipped -replace '\{id\}', $script.Id -replace '\{name\}', $script.Name
            Write-Log $msg -Level "skip"
        } else {
            $msg = $LogMessages.messages.dryRunItem -replace '\{id\}', $script.Id -replace '\{name\}', $script.Name -replace '\{desc\}', $script.Desc
            Write-Log $msg -Level "info"
        }
    }

    $enabledCount = @($ScriptList | Where-Object { $_.Enabled }).Count
    Write-Host ""
    Write-Log ($LogMessages.messages.dryRunComplete -replace '\{count\}', $enabledCount) -Level "success"
}