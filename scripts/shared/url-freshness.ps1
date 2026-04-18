# --------------------------------------------------------------------------
#  Shared helper: URL freshness validation
#  Sends HEAD requests to verify download URLs still resolve (HTTP 200).
# --------------------------------------------------------------------------

function Test-UrlFreshness {
    <#
    .SYNOPSIS
        Validates that a list of download URLs return HTTP 200 via HEAD request.
        Returns an array of objects with url, label, statusCode, and isAlive.

    .PARAMETER Items
        Array of objects with at minimum a downloadUrl property.

    .PARAMETER LabelField
        Property name to use as the friendly label (default: displayName).

    .PARAMETER TimeoutSec
        Timeout per request in seconds (default: 15).

    .PARAMETER WarnOnly
        If set, logs warnings for stale URLs but returns $true.
        If not set, returns $false when any URL is stale.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Items,

        [string]$LabelField = "displayName",

        [int]$TimeoutSec = 15,

        [switch]$WarnOnly
    )

    $results = @()
    $hasStaleUrls = $false

    foreach ($item in $Items) {
        $url   = $item.downloadUrl
        $label = if ($item.PSObject.Properties[$LabelField]) { $item.$LabelField } else { $url }

        $statusCode = 0
        $isAlive    = $false

        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
            $statusCode = $response.StatusCode
            $isAlive = $statusCode -eq 200
        } catch {
            # Try to extract status code from the exception
            $hasStatusCode = $null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode
            if ($hasStatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            } else {
                $statusCode = -1
            }
            $isAlive = $false
        }

        if ($isAlive) {
            Write-Log "  URL OK ($statusCode): $label" -Level "info"
        } else {
            $hasStaleUrls = $true
            Write-Log "  URL STALE ($statusCode): $label -- $url" -Level "warn"
        }

        $results += [PSCustomObject]@{
            Url        = $url
            Label      = $label
            StatusCode = $statusCode
            IsAlive    = $isAlive
        }
    }

    if ($hasStaleUrls -and -not $WarnOnly) {
        Write-Log "One or more download URLs are unreachable. Aborting." -Level "error"
        return $false
    }

    if ($hasStaleUrls -and $WarnOnly) {
        Write-Log "Some URLs are unreachable but continuing (warn-only mode)." -Level "warn"
    }

    return $true
}
