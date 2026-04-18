<#
.SYNOPSIS
    Shared timeout wrapper: runs a script block in a background job with
    a configurable timeout.  If the operation exceeds the limit it is
    forcefully terminated and a detailed log entry is written.
#>

# -- Bootstrap shared helpers --------------------------------------------------
$loggingPath = Join-Path $PSScriptRoot "logging.ps1"
if ((Test-Path $loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $loggingPath
}

if (-not (Get-Variable -Name SharedLogMessages -Scope Script -ErrorAction SilentlyContinue)) {
    $sharedLogPath = Join-Path $PSScriptRoot "log-messages.json"
    if (Test-Path $sharedLogPath) {
        $script:SharedLogMessages = Get-Content $sharedLogPath -Raw | ConvertFrom-Json
    }
}

function Invoke-WithTimeout {
    <#
    .SYNOPSIS
        Runs a script block inside a background job with a timeout guard.
        Returns a hashtable with Success, Output, Elapsed, and TimedOut keys.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [int]$TimeoutSecs = 120,

        [int]$PollSecs = 5
    )

    $slm = $script:SharedLogMessages

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Start the operation as a background job
    $job = Start-Job -ScriptBlock $ScriptBlock

    # Poll until completion or timeout
    $isComplete = $false
    $isTimedOut = $false

    while (-not $isComplete) {
        Start-Sleep -Seconds $PollSecs
        $elapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds, 0)

        $isJobDone = $job.State -in @('Completed', 'Failed', 'Stopped')
        if ($isJobDone) {
            $isComplete = $true
        }
        else {
            $hasExceededTimeout = $elapsed -ge $TimeoutSecs
            if ($hasExceededTimeout) {
                $isTimedOut = $true
                $isComplete = $true
            }
            else {
                Write-Log ($slm.messages.timeoutWaiting -replace '\{label\}', $Label -replace '\{elapsed\}', $elapsed -replace '\{limit\}', $TimeoutSecs) -Level "info"
            }
        }
    }

    $stopwatch.Stop()
    $totalElapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)

    if ($isTimedOut) {
        # Kill the job
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

        Write-Log ($slm.messages.timeoutExceeded -replace '\{label\}', $Label -replace '\{elapsed\}', $totalElapsed -replace '\{limit\}', $TimeoutSecs) -Level "error"
        Write-Log ($slm.messages.timeoutTerminated -replace '\{label\}', $Label) -Level "error"
        Write-Log ($slm.messages.timeoutHint -replace '\{label\}', $Label) -Level "info"

        return @{
            Success  = $false
            Output   = $null
            Elapsed  = $totalElapsed
            TimedOut = $true
        }
    }

    # Job finished -- collect output
    $jobOutput = $null
    $isJobFailed = $job.State -eq 'Failed'

    try {
        $jobOutput = Receive-Job -Job $job -ErrorAction Stop
    }
    catch {
        $isJobFailed = $true
        $jobOutput = $_.Exception.Message
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }

    if ($isJobFailed) {
        Write-Log ($slm.messages.timeoutJobFailed -replace '\{label\}', $Label -replace '\{elapsed\}', $totalElapsed -replace '\{error\}', $jobOutput) -Level "error"

        return @{
            Success  = $false
            Output   = $jobOutput
            Elapsed  = $totalElapsed
            TimedOut = $false
        }
    }

    Write-Log ($slm.messages.timeoutSuccess -replace '\{label\}', $Label -replace '\{elapsed\}', $totalElapsed) -Level "success"

    return @{
        Success  = $true
        Output   = $jobOutput
        Elapsed  = $totalElapsed
        TimedOut = $false
    }
}
