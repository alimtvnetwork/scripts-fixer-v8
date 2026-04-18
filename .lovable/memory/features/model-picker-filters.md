---
name: Model picker 4-filter chain
description: Interactive model picker has 4 sequential filters -- RAM, Size, Speed, Capability -- each optional with re-indexing
type: feature
---

## 4-Filter Chain (model-picker.ps1)

Order: `Read-RamFilter` -> `Read-SizeFilter` -> `Read-SpeedFilter` -> `Read-CapabilityFilter`

All filters are optional (Enter to skip). Each filter re-indexes surviving models from 1..N.

### RAM Filter
- Preset tiers: 4, 8, 16, 32, 64 GB
- Auto-detects system RAM via WMI
- Direct numeric input supported

### Size Filter
- Tiers: Tiny (<1 GB), Small (<3 GB), Medium (<6 GB), Large (<12 GB), XLarge (12+ GB)

### Speed Filter
- Tiers: Instant (<1 GB), Fast (<3 GB), Moderate (<8 GB), Slow (8+ GB)
- Shows model count per tier
- Supports multi-select (e.g. "1,2" for instant + fast)

### Capability Filter
- Categories: Coding, Reasoning, Writing, Chat, Voice, Multilingual
- OR logic: model shown if ANY selected capability matches
- Same selection syntax as model picker (single, range, comma-separated)

### Speed Tier Column (Display Only)
Computed at display time from `fileSizeGB`, shown in catalog table alongside Size and RAM columns.
