<# Bucket E: zoom -- Zoom Desktop cache (NOT recordings, NOT chats, NOT login) #>
param([switch]$DryRun, [switch]$Yes, [int]$Days = 30, [hashtable]$SharedResult)

$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $here "_sweep.ps1")

$result = New-CleanResult -Category "zoom" -Label "Zoom cache (recordings + chats + login SAFE)" -Bucket "E"

$appdata = Get-AppDataPath
$local   = Get-LocalAppDataPath
if ([string]::IsNullOrWhiteSpace($appdata) -or [string]::IsNullOrWhiteSpace($local)) {
    $result.Notes += "APPDATA / LOCALAPPDATA not set"
    Set-CleanResultStatus -Result $result -DryRun:$DryRun
    return $result
}

# Roots: %APPDATA%\Zoom and %LOCALAPPDATA%\Zoom (both exist on modern installs)
$zoomRoots = @(
    (Join-Path $appdata "Zoom"),
    (Join-Path $local   "Zoom")
)

# Cache-only subpaths -- explicitly EXCLUDES:
#   - data\        (chat history, contacts, settings)
#   - logs\        (kept for diagnostics; user can wipe via UI)
#   - bin\, installer\  (binaries)
#   - <userhome>\Documents\Zoom  (LOCAL RECORDINGS -- never touched)
$cacheSubs = @(
    "Cache",
    "GPUCache",
    "Code Cache",
    "blob_storage",
    "data\Cache",
    "data\VideoMail\cache",
    "data\file_transfer\Cache",
    "Temp"
)

$anyFound = $false
foreach ($root in $zoomRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $anyFound = $true
    foreach ($sub in $cacheSubs) {
        $p = Join-Path $root $sub
        if (Test-Path -LiteralPath $p) {
            Invoke-PathSweep -Path $p -Result $result -DryRun:$DryRun -LogPrefix "zoom/$sub"
        }
    }
}

if (-not $anyFound) {
    $result.Notes += "Zoom not installed"
}

Set-CleanResultStatus -Result $result -DryRun:$DryRun
return $result
