# --------------------------------------------------------------------------
#  Ollama Hub search -- queries ollama.com/search and parses results.
#  Used by `.\run.ps1 models search <query>` (see spec/models/readme.md).
# --------------------------------------------------------------------------

function Invoke-OllamaHubSearch {
    <#
    .SYNOPSIS
        Hits https://ollama.com/search?q=<query> and returns parsed model entries.
    .OUTPUTS
        Array of [PSCustomObject] with: slug, displayName, description,
        sizes, capabilities, pulls, tags, url, pullCommand.
        Returns empty array on failure (logs the error -- never throws).
    #>
    param(
        [Parameter(Mandatory)] [string]$Query,
        [int]$TimeoutSec = 15
    )

    $isQueryEmpty = [string]::IsNullOrWhiteSpace($Query)
    if ($isQueryEmpty) {
        Write-Log "Ollama search query is empty -- nothing to do." -Level "warn"
        return @()
    }

    $encoded = [System.Uri]::EscapeDataString($Query.Trim())
    $url     = "https://ollama.com/search?q=$encoded"
    Write-Log "Querying Ollama Hub: $url" -Level "info"

    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec `
            -UserAgent "scripts-fixer/models-search (PowerShell)" -ErrorAction Stop
        $html = $response.Content
    } catch {
        Write-Log "Ollama Hub request failed: $_" -Level "error"
        Write-FileError -FilePath $url -Operation "fetch" -Reason "$_" -Module "Invoke-OllamaHubSearch"
        return @()
    }

    $isHtmlEmpty = [string]::IsNullOrWhiteSpace($html)
    if ($isHtmlEmpty) {
        Write-Log "Ollama Hub returned an empty response body." -Level "warn"
        return @()
    }

    return ConvertFrom-OllamaHubHtml -Html $html
}

function ConvertFrom-OllamaHubHtml {
    <#
    .SYNOPSIS
        Parses ollama.com search HTML into structured model objects.
        Anchored on stable `x-test-*` attributes the site exposes for testing.
    #>
    param([Parameter(Mandatory)] [string]$Html)

    # Each result is a <li x-test-model=""> ... </li> block.
    # Use a non-greedy match anchored on the marker + closing tag.
    $blocks = [regex]::Matches($Html, '(?s)<li[^>]*x-test-model[^>]*>.*?</li>')
    $hasBlocks = $blocks.Count -gt 0
    if (-not $hasBlocks) {
        Write-Log "No model blocks found in Ollama Hub HTML (page format may have changed)." -Level "warn"
        return @()
    }

    $results = @()
    foreach ($block in $blocks) {
        $b = $block.Value

        # Slug + URL: href can be absolute (https://ollama.com/library/<slug>) or
        # relative (/library/<slug>). Accept both shapes.
        $slug = $null
        $urlVal = $null
        $hrefMatch = [regex]::Match($b, 'href="(?:https://ollama\.com)?(/library/([^"]+))"')
        if ($hrefMatch.Success) {
            $relPath = $hrefMatch.Groups[1].Value
            $slug    = $hrefMatch.Groups[2].Value
            $urlVal  = "https://ollama.com$relPath"
        }
        $hasSlug = -not [string]::IsNullOrWhiteSpace($slug)
        if (-not $hasSlug) { continue }

        # Display name: <span x-test-search-response-title="">name</span>
        $displayName = $slug
        $titleMatch = [regex]::Match($b, '(?s)x-test-search-response-title[^>]*>\s*([^<]+?)\s*<')
        if ($titleMatch.Success) { $displayName = $titleMatch.Groups[1].Value.Trim() }

        # Description: first <p class="max-w-lg ...">desc</p>
        $description = ""
        $descMatch = [regex]::Match($b, '(?s)<p[^>]*max-w-lg[^>]*>\s*(.*?)\s*</p>')
        if ($descMatch.Success) {
            $description = $descMatch.Groups[1].Value -replace '\s+', ' '
            $description = $description.Trim()
        }

        # Sizes: <span x-test-size="">7b</span>
        $sizes = @()
        $sizeMatches = [regex]::Matches($b, '(?s)x-test-size[^>]*>\s*([^<]+?)\s*<')
        foreach ($m in $sizeMatches) { $sizes += $m.Groups[1].Value.Trim() }

        # Capabilities: <span x-test-capability="">tools</span>
        $capabilities = @()
        $capMatches = [regex]::Matches($b, '(?s)x-test-capability[^>]*>\s*([^<]+?)\s*<')
        foreach ($m in $capMatches) { $capabilities += $m.Groups[1].Value.Trim() }

        # Pulls: <span x-test-pull-count="">4.4M</span>
        $pulls = ""
        $pullMatch = [regex]::Match($b, '(?s)x-test-pull-count[^>]*>\s*([^<]+?)\s*<')
        if ($pullMatch.Success) { $pulls = $pullMatch.Groups[1].Value.Trim() }

        # Tag count: <span x-test-tag-count="">68</span>
        $tags = ""
        $tagMatch = [regex]::Match($b, '(?s)x-test-tag-count[^>]*>\s*([^<]+?)\s*<')
        if ($tagMatch.Success) { $tags = $tagMatch.Groups[1].Value.Trim() }

        # Updated: <span x-test-updated="">1 year ago</span>
        $updated = ""
        $updMatch = [regex]::Match($b, '(?s)x-test-updated[^>]*>\s*([^<]+?)\s*<')
        if ($updMatch.Success) { $updated = $updMatch.Groups[1].Value.Trim() }

        $results += [PSCustomObject]@{
            slug         = $slug
            displayName  = $displayName
            description  = $description
            sizes        = $sizes
            capabilities = $capabilities
            pulls        = $pulls
            tags         = $tags
            updated      = $updated
            url          = $urlVal
            pullCommand  = $slug
            backend      = "ollama"
        }
    }

    return $results
}

function Show-OllamaHubResults {
    <#
    .SYNOPSIS
        Pretty-prints search results as a numbered table.
    #>
    param(
        [Parameter(Mandatory)] [array]$Results,
        [string]$Query
    )

    Write-Host ""
    Write-Host "  Ollama Hub results for `"$Query`": $($Results.Count) models" -ForegroundColor Cyan
    Write-Host ""

    $colNum   = 5
    $colSlug  = 28
    $colSizes = 22
    $colCaps  = 16
    $colPulls = 8

    Write-Host ("  {0,-$colNum} {1,-$colSlug} {2,-$colSizes} {3,-$colCaps} {4,-$colPulls} {5}" -f "#", "Slug", "Sizes", "Caps", "Pulls", "Description") -ForegroundColor Yellow
    Write-Host ("  " + ("-" * 110)) -ForegroundColor DarkGray

    $idx = 1
    foreach ($r in $Results) {
        $sizesStr = ($r.sizes -join ", ")
        if ($sizesStr.Length -gt ($colSizes - 2)) { $sizesStr = $sizesStr.Substring(0, $colSizes - 4) + ".." }
        $capsStr  = ($r.capabilities -join ", ")
        if ($capsStr.Length -gt ($colCaps - 2)) { $capsStr = $capsStr.Substring(0, $colCaps - 4) + ".." }
        $slugStr = $r.slug
        if ($slugStr.Length -gt ($colSlug - 2)) { $slugStr = $slugStr.Substring(0, $colSlug - 4) + ".." }
        $descShort = if ($r.description.Length -gt 60) { $r.description.Substring(0, 58) + ".." } else { $r.description }

        Write-Host ("  {0,-$colNum} {1,-$colSlug} {2,-$colSizes} {3,-$colCaps} {4,-$colPulls} {5}" -f "[$idx]", $slugStr, $sizesStr, $capsStr, $r.pulls, $descShort) -ForegroundColor White
        $idx++
    }
    Write-Host ""
}

function Read-OllamaHubSelection {
    <#
    .SYNOPSIS
        Prompts user to pick results to pull. Supports numbers, ranges, "all", "q".
        Returns array of selected indices (1-based) or $null to quit.
    #>
    param([int]$MaxIndex)

    Write-Host "  Select models to pull (or [Enter] to skip, [q] to quit):" -ForegroundColor Cyan
    Write-Host "    Examples: 1,3,5  |  1-3  |  all" -ForegroundColor DarkGray
    Write-Host "    You can also append a tag, e.g. '2:7b' to pull a specific size." -ForegroundColor DarkGray
    Write-Host ""
    $input = Read-Host -Prompt "  Your selection"
    $trimmed = $input.Trim().ToLower()

    $isEmpty = [string]::IsNullOrWhiteSpace($trimmed)
    if ($isEmpty) { return @() }
    if ($trimmed -eq "q" -or $trimmed -eq "quit") { return $null }
    if ($trimmed -eq "all") { return @(1..$MaxIndex | ForEach-Object { @{ Index = $_; Tag = $null } }) }

    $selections = @()
    $parts = $trimmed -split ","
    foreach ($part in $parts) {
        $part = $part.Trim()
        # Tag suffix support: "2:7b"
        $tag = $null
        if ($part -match '^([\d\-]+):([^\s]+)$') {
            $part = $Matches[1]
            $tag  = $Matches[2]
        }

        $isRange = $part -match "^(\d+)\s*-\s*(\d+)$"
        if ($isRange) {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            if ($a -gt $b) { $a, $b = $b, $a }
            for ($i = $a; $i -le $b; $i++) {
                if ($i -ge 1 -and $i -le $MaxIndex) { $selections += @{ Index = $i; Tag = $tag } }
            }
        } elseif ($part -match "^\d+$") {
            $n = [int]$part
            if ($n -ge 1 -and $n -le $MaxIndex) { $selections += @{ Index = $n; Tag = $tag } }
        }
    }
    return $selections
}
