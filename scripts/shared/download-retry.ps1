<#
.SYNOPSIS
    Shared download helper: wraps Invoke-WebRequest with configurable
    retry count and exponential backoff for resilient large-file downloads.
#>

# -- Bootstrap shared helpers --------------------------------------------------
$loggingPath = Join-Path $PSScriptRoot "logging.ps1"
if ((Test-Path $loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $loggingPath
}

function Invoke-DownloadWithRetry {
    <#
    .SYNOPSIS
        Downloads a file with automatic retry on failure.
        Returns $true on success, $false on exhausted retries.
    .PARAMETER Uri
        The URL to download from.
    .PARAMETER OutFile
        Local file path to save the download.
    .PARAMETER MaxRetries
        Maximum number of attempts (default: 3).
    .PARAMETER BaseDelaySec
        Base delay in seconds; doubles each retry (default: 5).
    .PARAMETER Label
        Friendly name for log messages (e.g. "OllamaSetup.exe").
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [int]$MaxRetries = 3,

        [int]$BaseDelaySec = 5,

        [string]$Label = ""
    )

    $displayLabel = if ($Label) { $Label } else { [System.IO.Path]::GetFileName($OutFile) }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $ProgressPreference = "SilentlyContinue"
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
            $ProgressPreference = "Continue"

            # Verify file was actually written
            $isFilePresent = Test-Path $OutFile
            if (-not $isFilePresent) {
                throw "File not found after download: $OutFile"
            }

            $fileInfo = Get-Item $OutFile
            $isFileEmpty = $fileInfo.Length -eq 0
            if ($isFileEmpty) {
                throw "Downloaded file is empty (0 bytes): $OutFile"
            }

            $sizeMB = [math]::Round($fileInfo.Length / (1024 * 1024), 2)
            Write-Log "Downloaded $displayLabel ($sizeMB MB) on attempt $attempt" -Level "success"
            return $true
        }
        catch {
            $isLastAttempt = $attempt -eq $MaxRetries
            if ($isLastAttempt) {
                Write-Log "Download failed for $displayLabel after $MaxRetries attempts: $_" -Level "error"
                # Clean up partial file
                $hasPartialFile = Test-Path $OutFile
                if ($hasPartialFile) {
                    Remove-Item -Path $OutFile -Force -ErrorAction SilentlyContinue
                }
                return $false
            }

            $delay = $BaseDelaySec * [math]::Pow(2, $attempt - 1)
            Write-Log "Download attempt $attempt/$MaxRetries failed for $displayLabel -- retrying in ${delay}s: $_" -Level "warn"
            Start-Sleep -Seconds $delay
        }
    }

    return $false
}
