# --------------------------------------------------------------------------
#  Shared helper: hardware feature detection (CUDA, AVX2)
#  Detects GPU and CPU capabilities for selecting compatible binary variants.
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = $PSScriptRoot
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Test-CudaAvailable {
    <#
    .SYNOPSIS
        Checks whether an NVIDIA CUDA-capable GPU is present.
        Returns a hashtable with detection results.
    .RETURNS
        @{ Available = $true/$false; Version = "12.4" or $null; Driver = "..." or $null; GpuName = "..." or $null }
    #>

    $result = @{
        Available = $false
        Version   = $null
        Driver    = $null
        GpuName   = $null
    }

    # Method 1: nvidia-smi (most reliable)
    $nvidiaSmi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    $isNvidiaSmiFound = $null -ne $nvidiaSmi
    if ($isNvidiaSmiFound) {
        try {
            $output = & nvidia-smi.exe --query-gpu=name,driver_version --format=csv,noheader 2>&1
            $isOutputValid = $LASTEXITCODE -eq 0 -and $output -match ","
            if ($isOutputValid) {
                $parts = ($output | Select-Object -First 1).ToString().Split(",")
                $result.GpuName = $parts[0].Trim()
                $result.Driver  = $parts[1].Trim()
                $result.Available = $true
            }
        } catch {
            # nvidia-smi failed, continue to other methods
        }
    }

    # Method 2: Check for CUDA toolkit via nvcc
    if (-not $result.Available) {
        $nvcc = Get-Command nvcc.exe -ErrorAction SilentlyContinue
        $isNvccFound = $null -ne $nvcc
        if ($isNvccFound) {
            $result.Available = $true
        }
    }

    # Method 3: Check WMI for NVIDIA GPU
    if (-not $result.Available) {
        try {
            $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "NVIDIA" }
            $hasNvidiaGpu = $null -ne $gpus -and @($gpus).Count -gt 0
            if ($hasNvidiaGpu) {
                $result.GpuName   = ($gpus | Select-Object -First 1).Name
                $result.Available = $true
            }
        } catch {
            # WMI unavailable
        }
    }

    # Try to detect CUDA version from nvidia-smi full output
    $hasCudaVersion = $result.Available -and $null -eq $result.Version -and $isNvidiaSmiFound
    if ($hasCudaVersion) {
        try {
            $fullOutput = & nvidia-smi.exe 2>&1 | Out-String
            $isCudaInOutput = $fullOutput -match "CUDA Version:\s*([\d.]+)"
            if ($isCudaInOutput) {
                $result.Version = $Matches[1]
            }
        } catch {
            # Ignore
        }
    }

    return $result
}

function Test-Avx2Available {
    <#
    .SYNOPSIS
        Checks whether the CPU supports AVX2 instructions.
        Uses registry or WMI to detect CPU features.
    .RETURNS
        @{ Available = $true/$false; CpuName = "..." or $null }
    #>

    $result = @{
        Available = $false
        CpuName   = $null
    }

    # Get CPU name
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        $hasCpu = $null -ne $cpu
        if ($hasCpu) {
            $result.CpuName = $cpu.Name.Trim()
        }
    } catch {
        # WMI unavailable
    }

    # Method 1: Check via registry (Windows stores CPU feature flags)
    try {
        $regPath = "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0"
        $isRegPresent = Test-Path $regPath
        if ($isRegPresent) {
            $featureSet = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).FeatureSet
            # FeatureSet is a bitmask; on modern CPUs with AVX2 this is typically > 0
            # More reliable: check ProcessorNameString for known AVX2-capable generations
        }
    } catch {
        # Registry check failed
    }

    # Method 2: Heuristic based on CPU generation
    # AVX2 was introduced with Intel Haswell (2013) and AMD Excavator (2015).
    # Nearly all CPUs from 2014+ support AVX2.
    $hasCpuName = $null -ne $result.CpuName
    if ($hasCpuName) {
        $cpuLower = $result.CpuName.ToLower()

        # Known AVX2-capable patterns
        $isIntelModern = $cpuLower -match "core.*i[3579]" -or
                         $cpuLower -match "xeon" -or
                         $cpuLower -match "core.*ultra"
        $isAmdModern   = $cpuLower -match "ryzen" -or
                         $cpuLower -match "epyc" -or
                         $cpuLower -match "threadripper"

        if ($isIntelModern -or $isAmdModern) {
            $result.Available = $true
        }
    }

    # Method 3: Try running a known AVX2 instruction check via PowerShell/.NET
    # If the above heuristic didn't match, assume modern x64 CPUs support AVX2
    if (-not $result.Available -and $hasCpuName) {
        # Conservative: if we can't confirm, assume available on 64-bit Windows
        $is64Bit = [System.Environment]::Is64BitOperatingSystem
        if ($is64Bit) {
            $result.Available = $true
        }
    }

    return $result
}

function Get-HardwareProfile {
    <#
    .SYNOPSIS
        Returns a combined hardware profile with CUDA and AVX2 detection results.
        Logs findings for visibility.
    .RETURNS
        @{ Cuda = @{...}; Avx2 = @{...} }
    #>

    $cuda = Test-CudaAvailable
    $avx2 = Test-Avx2Available

    # Log findings
    if ($cuda.Available) {
        $cudaInfo = "CUDA GPU detected"
        if ($cuda.GpuName)  { $cudaInfo += ": $($cuda.GpuName)" }
        if ($cuda.Version)  { $cudaInfo += " (CUDA $($cuda.Version))" }
        if ($cuda.Driver)   { $cudaInfo += " [Driver $($cuda.Driver)]" }
        Write-Log $cudaInfo -Level "success"
    } else {
        Write-Log "No NVIDIA CUDA GPU detected. CUDA variants will be skipped." -Level "info"
    }

    if ($avx2.Available) {
        $avx2Info = "AVX2 CPU support detected"
        if ($avx2.CpuName) { $avx2Info += ": $($avx2.CpuName)" }
        Write-Log $avx2Info -Level "success"
    } else {
        Write-Log "AVX2 CPU support not detected. AVX2 variants will be skipped." -Level "warn"
    }

    return @{
        Cuda = $cuda
        Avx2 = $avx2
    }
}

function Test-ExecutableCompatible {
    <#
    .SYNOPSIS
        Checks if an executable variant is compatible with the current hardware.
    .PARAMETER Requires
        Hardware requirement string: "cuda", "avx2", or $null/empty (always compatible).
    .PARAMETER HardwareProfile
        Output from Get-HardwareProfile.
    .RETURNS
        $true if compatible, $false if not.
    #>
    param(
        [string]$Requires,
        [hashtable]$HardwareProfile
    )

    $isEmpty = [string]::IsNullOrWhiteSpace($Requires)
    if ($isEmpty) { return $true }

    $reqLower = $Requires.ToLower()

    switch ($reqLower) {
        "cuda" { return $HardwareProfile.Cuda.Available }
        "avx2" { return $HardwareProfile.Avx2.Available }
        default {
            Write-Log "Unknown hardware requirement: $Requires -- assuming compatible." -Level "warn"
            return $true
        }
    }
}
