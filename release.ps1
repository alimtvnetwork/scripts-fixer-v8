<#
.SYNOPSIS
    Release pipeline -- packages project assets into versioned ZIP archives.

.DESCRIPTION
    Reads the current version from .gitmap/release/latest.json, then creates
    a ZIP containing scripts/, run.ps1, and supporting root files inside the
    .release/ directory.

    The output ZIP is named: dev-tools-setup-v<version>.zip

.PARAMETER Force
    Overwrite an existing ZIP for the same version without prompting.

.PARAMETER DryRun
    Show what would be packaged without creating the ZIP.

.EXAMPLE
    .\release.ps1                   # build release ZIP for current version
    .\release.ps1 -DryRun           # preview contents without creating ZIP
    .\release.ps1 -Force            # overwrite existing ZIP if present

.NOTES
    Author : Lovable AI
    Version: 1.0.0
#>

param(
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Read version ─────────────────────────────────────────────────────
$latestFile = Join-Path $RootDir ".gitmap" "release" "latest.json"
$isLatestMissing = -not (Test-Path $latestFile)
if ($isLatestMissing) {
    Write-Host "[ FAIL ] .gitmap/release/latest.json not found." -ForegroundColor Red
    exit 1
}

$latestData = Get-Content $latestFile -Raw | ConvertFrom-Json
$version = $latestData.version
$tag     = $latestData.tag

Write-Host ""
Write-Host "  Release Pipeline" -ForegroundColor Cyan
Write-Host "  ================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Version : $version" -ForegroundColor White
Write-Host "  Tag     : $tag" -ForegroundColor White
Write-Host ""

# ── Prepare output directory ─────────────────────────────────────────
$releaseDir = Join-Path $RootDir ".release"
$isReleaseDirMissing = -not (Test-Path $releaseDir)
if ($isReleaseDirMissing) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    Write-Host "  [ OK ] Created .release/ directory" -ForegroundColor Green
}

$zipName = "dev-tools-setup-v$version.zip"
$zipPath = Join-Path $releaseDir $zipName

# ── Check existing ZIP ───────────────────────────────────────────────
$isZipExists = Test-Path $zipPath
if ($isZipExists -and -not $Force -and -not $DryRun) {
    Write-Host "  [ SKIP ] $zipName already exists. Use -Force to overwrite." -ForegroundColor Yellow
    exit 0
}

# ── Collect files to package ─────────────────────────────────────────
$includeItems = @(
    @{ Source = "scripts";           Type = "directory" }
    @{ Source = "run.ps1";           Type = "file" }
    @{ Source = "bump-version.ps1";  Type = "file" }
    @{ Source = "readme.md";         Type = "file" }
    @{ Source = "LICENSE";           Type = "file" }
    @{ Source = "changelog.md";      Type = "file" }
)

$stagingDir = Join-Path $env:TEMP "dev-tools-release-$version"

# ── DryRun mode ──────────────────────────────────────────────────────
if ($DryRun) {
    Write-Host "  [ DRY RUN ] Would create: $zipName" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Contents:" -ForegroundColor Yellow

    foreach ($item in $includeItems) {
        $sourcePath = Join-Path $RootDir $item.Source
        $isSourcePresent = Test-Path $sourcePath

        if ($isSourcePresent) {
            $icon = if ($item.Type -eq "directory") { "[DIR ]" } else { "[FILE]" }
            Write-Host "    $icon $($item.Source)" -ForegroundColor Green
        }
        else {
            Write-Host "    [MISS] $($item.Source)" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "  Output: .release/$zipName" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# ── Stage files ──────────────────────────────────────────────────────
Write-Host "  Staging files..." -ForegroundColor DarkGray

$isStagingExists = Test-Path $stagingDir
if ($isStagingExists) {
    Remove-Item $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

$fileCount = 0
foreach ($item in $includeItems) {
    $sourcePath = Join-Path $RootDir $item.Source
    $destPath   = Join-Path $stagingDir $item.Source
    $isSourcePresent = Test-Path $sourcePath

    if (-not $isSourcePresent) {
        Write-Host "  [ WARN ] Skipping missing: $($item.Source)" -ForegroundColor Yellow
        continue
    }

    if ($item.Type -eq "directory") {
        Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
        $dirFileCount = (Get-ChildItem $destPath -Recurse -File).Count
        $fileCount += $dirFileCount
        Write-Host "  [ OK ] $($item.Source)/ ($dirFileCount files)" -ForegroundColor Green
    }
    else {
        $parentDir = Split-Path $destPath -Parent
        $isParentMissing = -not (Test-Path $parentDir)
        if ($isParentMissing) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        $fileCount++
        Write-Host "  [ OK ] $($item.Source)" -ForegroundColor Green
    }
}

# ── Create ZIP ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Compressing $fileCount files..." -ForegroundColor DarkGray

if ($isZipExists) {
    Remove-Item $zipPath -Force
}

Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath -CompressionLevel Optimal

$zipSize = (Get-Item $zipPath).Length
$zipSizeKB = [math]::Round($zipSize / 1024, 1)
$zipSizeMB = [math]::Round($zipSize / 1048576, 2)

$sizeLabel = if ($zipSizeMB -ge 1) { "$zipSizeMB MB" } else { "$zipSizeKB KB" }

Write-Host "  [ OK ] Created: .release/$zipName ($sizeLabel)" -ForegroundColor Green

# ── Cleanup staging ──────────────────────────────────────────────────
Remove-Item $stagingDir -Recurse -Force
Write-Host "  [ OK ] Cleaned up staging directory" -ForegroundColor Green

# ── Done ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Release $tag packaged successfully!" -ForegroundColor Magenta
Write-Host "  Output: .release/$zipName" -ForegroundColor DarkGray
Write-Host ""
