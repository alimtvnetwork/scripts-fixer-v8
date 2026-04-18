# --------------------------------------------------------------------------
#  Orchestrator helper -- Front-loaded questionnaire
#  Asks all config questions upfront and stores answers in env vars.
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Show-QuickMenu {
    <#
    .SYNOPSIS
        Shows the top-level 3-option menu:
        1) All Dev (no DBs)
        2) All Dev + All DBs
        3) Custom (pick individually)
        Returns: "alldev", "alldev+db", "custom", or "quit"
    #>
    param($LogMessages)

    Write-Host ""
    Write-Host "  What would you like to do?" -ForegroundColor Cyan
    Write-Host "  ===========================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    [1] " -NoNewline -ForegroundColor Yellow
    Write-Host "All Dev Tools" -NoNewline
    Write-Host " (VS Code, Node.js, Python, Go, Git, C++, PHP, PowerShell)" -ForegroundColor DarkGray
    Write-Host "    [2] " -NoNewline -ForegroundColor Yellow
    Write-Host "All Dev Tools + All Databases" -NoNewline
    Write-Host " (everything above + MySQL, PostgreSQL, MongoDB, etc.)" -ForegroundColor DarkGray
    Write-Host "    [3] " -NoNewline -ForegroundColor Yellow
    Write-Host "All Databases Only" -NoNewline
    Write-Host " (MySQL, MariaDB, PostgreSQL, SQLite, MongoDB, Redis, etc.)" -ForegroundColor DarkGray
    Write-Host "    [4] " -NoNewline -ForegroundColor Yellow
    Write-Host "Custom" -NoNewline
    Write-Host " (pick individual tools from the full list)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    [U] " -NoNewline -ForegroundColor Red
    Write-Host "Uninstall" -NoNewline
    Write-Host " (remove installed tools -- pick from list)" -ForegroundColor DarkGray
    Write-Host "    [Q] " -NoNewline -ForegroundColor Yellow
    Write-Host "Quit"
    Write-Host ""

    $choice = Read-Host "  Choose [1/2/3/4/U/Q] (default: 1)"
    $choice = $choice.Trim().ToUpper()

    $isUninstall = $choice -eq "U"
    if ($isUninstall) { return "uninstall" }

    $isQuit = $choice -eq "Q"
    if ($isQuit) { return "quit" }

    $isAllDevDb = $choice -eq "2"
    if ($isAllDevDb) { return "alldev+db" }

    $isAllDb = $choice -eq "3"
    if ($isAllDb) { return "alldb" }

    $isCustom = $choice -eq "4"
    if ($isCustom) { return "custom" }

    # Default: 1 = alldev
    return "alldev"
}

function Invoke-Questionnaire {
    <#
    .SYNOPSIS
        Asks all configuration questions upfront based on what's going to be installed.
        Stores answers in environment variables so child scripts skip their own prompts.
        When -UseDefaults is set, all questions are answered with defaults automatically.
    #>
    param(
        [string]$Mode,
        $Config,
        $LogMessages,
        [switch]$UseDefaults
    )

    Write-Host ""
    Write-Host "  Configuration" -ForegroundColor Cyan
    Write-Host "  ------------" -ForegroundColor DarkGray
    Write-Host ""

    # ── Q1: Dev directory ────────────────────────────────────────────────────
    $defaultDevDir = $Config.devDir.default
    $hasOverride = -not [string]::IsNullOrWhiteSpace($Config.devDir.override)
    if ($hasOverride) { $defaultDevDir = $Config.devDir.override }

    if ($UseDefaults) {
        $devDirInput = $defaultDevDir
    } else {
        Write-Host "  Dev directory -- tools, configs, data will be stored here" -ForegroundColor Yellow
        Write-Host "  (use -Path parameter to override, e.g. .\run.ps1 -Path F:\dev-tool)" -ForegroundColor DarkGray
        $devDirInput = Read-Host "  Path (default: $defaultDevDir)"
        $isDefaultDevDir = [string]::IsNullOrWhiteSpace($devDirInput)
        if ($isDefaultDevDir) { $devDirInput = $defaultDevDir }
    }
    $env:DEV_DIR = $devDirInput
    Write-Log "Dev directory: $devDirInput" -Level "success"

    # ── Q2: VS Code editions (only if installing dev tools) ──────────────────
    $isInstallingDev = $Mode -eq "alldev" -or $Mode -eq "alldev+db"
    if ($isInstallingDev) {
        if ($UseDefaults) {
            $vscEditions = "stable"
        } else {
            Write-Host ""
            Write-Host "  VS Code editions to install:" -ForegroundColor Yellow
            Write-Host "    [1] " -NoNewline -ForegroundColor Cyan
            Write-Host "Stable only (default)"
            Write-Host "    [2] " -NoNewline -ForegroundColor Cyan
            Write-Host "Insiders only"
            Write-Host "    [3] " -NoNewline -ForegroundColor Cyan
            Write-Host "Both Stable + Insiders"

            $vscChoice = Read-Host "  Choose [1/2/3] (default: 1)"
            $vscEditions = switch ($vscChoice) {
                "2" { "insiders" }
                "3" { "stable,insiders" }
                default { "stable" }
            }
        }
        $env:VSCODE_EDITIONS = $vscEditions
        Write-Log "VS Code editions: $vscEditions" -Level "success"
    }

    # ── Q3: VS Code settings sync ───────────────────────────────────────────
    if ($isInstallingDev) {
        if ($UseDefaults) {
            $env:VSCODE_SYNC_MODE = "overwrite"
        } else {
            Write-Host ""
            Write-Host "  Sync VS Code settings (keybindings, extensions, preferences)?" -ForegroundColor Yellow
            Write-Host "    [1] " -NoNewline -ForegroundColor Cyan
            Write-Host "Yes, overwrite existing settings (default)"
            Write-Host "    [2] " -NoNewline -ForegroundColor Cyan
            Write-Host "Yes, merge with existing settings"
            Write-Host "    [3] " -NoNewline -ForegroundColor Cyan
            Write-Host "No, skip settings sync"

            $syncChoice = Read-Host "  Choose [1/2/3] (default: 1)"
            $env:VSCODE_SYNC_MODE = switch ($syncChoice) {
                "2" { "merge" }
                "3" { "skip" }
                default { "overwrite" }
            }
        }
        Write-Log "VS Code sync: $($env:VSCODE_SYNC_MODE)" -Level "success"
    }

    # ── Q4: Git user.name ────────────────────────────────────────────────────
    if ($isInstallingDev) {
        $currentGitName = ""
        try { $currentGitName = & git config --global user.name 2>$null } catch {}
        $hasGitName = -not [string]::IsNullOrWhiteSpace($currentGitName)

        if ($hasGitName) {
            if (-not $UseDefaults) {
                Write-Host ""
                Write-Host "  Git user.name already set: $currentGitName" -ForegroundColor DarkGray
            }
            $env:GIT_USER_NAME = $currentGitName
        } elseif (-not $UseDefaults) {
            Write-Host ""
            $gitName = Read-Host "  Git user.name (your full name, or press Enter to skip)"
            $hasInput = -not [string]::IsNullOrWhiteSpace($gitName)
            if ($hasInput) {
                $env:GIT_USER_NAME = $gitName
                Write-Log "Git user.name: $gitName" -Level "success"
            }
        }
    }

    # ── Q5: Git user.email ───────────────────────────────────────────────────
    if ($isInstallingDev) {
        $currentGitEmail = ""
        try { $currentGitEmail = & git config --global user.email 2>$null } catch {}
        $hasGitEmail = -not [string]::IsNullOrWhiteSpace($currentGitEmail)

        if ($hasGitEmail) {
            if (-not $UseDefaults) {
                Write-Host "  Git user.email already set: $currentGitEmail" -ForegroundColor DarkGray
            }
            $env:GIT_USER_EMAIL = $currentGitEmail
        } elseif (-not $UseDefaults) {
            $gitEmail = Read-Host "  Git user.email (or press Enter to skip)"
            $hasInput = -not [string]::IsNullOrWhiteSpace($gitEmail)
            if ($hasInput) {
                $env:GIT_USER_EMAIL = $gitEmail
                Write-Log "Git user.email: $gitEmail" -Level "success"
            }
        }
    }

    Write-Host ""
    Write-Log "All questions answered -- starting installation..." -Level "success"
    Write-Host ""
}

function Get-ScriptListForMode {
    <#
    .SYNOPSIS
        Returns the script list for the chosen mode.
    #>
    param(
        [string]$Mode,
        $Config
    )

    $allDevIds = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "16", "17", "31")
    $allDbIds  = @("18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29")

    $selectedIds = switch ($Mode) {
        "alldev"    { $allDevIds }
        "alldev+db" { $allDevIds + $allDbIds }
        "alldb"     { $allDbIds }
        default     { @() }
    }

    # Build script list from config
    $result = New-Object System.Collections.ArrayList
    foreach ($id in $Config.sequence) {
        $isSelected = $id -in $selectedIds
        $hasNoSelection = -not $isSelected
        if ($hasNoSelection) { continue }

        $entry = $Config.scripts.$id
        $hasNoEntry = -not $entry
        if ($hasNoEntry) { continue }

        [void]$result.Add(@{
            Id      = $id
            Folder  = $entry.folder
            Name    = $entry.name
            Desc    = if ($entry.desc) { $entry.desc } else { "" }
            Enabled = $entry.enabled
        })
    }

    return ,@($result)
}
