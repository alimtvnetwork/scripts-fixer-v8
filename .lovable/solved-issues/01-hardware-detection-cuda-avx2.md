---
name: CUDA and AVX2 hardware detection for Script 43
description: Executable variants were downloaded regardless of hardware compatibility
resolved: 2026-04-16
version: v0.25.x
---

# CUDA/AVX2 Hardware Detection

## Problem
Script 43 (install-llama-cpp) downloaded ALL executable variants (CUDA, AVX2, KoboldCPP)
regardless of whether the user's hardware supported them. CUDA binaries are useless
without an NVIDIA GPU, and AVX2 binaries crash on older CPUs.

## Root Cause
No hardware detection was performed before downloading executables. The config.json
had a `requires` field per variant but nothing checked it.

## Solution
- Created `scripts/shared/hardware-detect.ps1` with `Get-HardwareProfile`
- Detects CUDA via nvidia-smi, nvcc, and WMI GPU name matching
- Detects AVX2 via WMI CPU model heuristic
- `Install-LlamaCppExecutables` now skips variants whose `requires` field
  does not match detected hardware
- Clear logging shows which variants are skipped and why

## Learning
- Always check hardware capabilities before downloading large binaries
- WMI is reliable for GPU/CPU detection on Windows
- Heuristic detection (GPU name matching) needs fallback to actual tool checks
