---
name: RAM-based model filtering
description: Users had no way to filter models by available RAM, leading to selection of incompatible models
resolved: 2026-04-16
version: v0.25.x
---

# RAM-Based Model Filtering

## Problem
The model catalog showed all 69+ models regardless of the user's available RAM.
Users could select models requiring 32+ GB RAM on an 8 GB machine, leading to
failed loads or extreme swapping.

## Solution
- Added `Read-RamFilter` function to model-picker.ps1
- Auto-detects system RAM via `Get-CimInstance Win32_OperatingSystem`
- Offers preset tiers (4, 8, 16, 32, 64 GB) plus detected RAM option
- Accepts direct numeric input for custom limits
- Filters models where `ramRequiredGB <= selected limit`
- Re-indexes remaining models for clean numbered display

## Learning
- Always offer hardware-aware filtering for resource-intensive downloads
- WMI `TotalVisibleMemorySize` gives available physical RAM reliably
- Filter chain order matters: RAM first (broadest cut), then size, speed, capability
