---
name: Notepad++ settings sync
description: After installing Notepad++, extract settings zip to %APPDATA%\Notepad++. Three modes: NPP + Settings, NPP Settings, Install NPP.
type: feature
---
Three installation modes for Notepad++ (NPP = Notepad++):

1. **NPP + Settings** (`install+settings`) -- install + extract settings zip (default)
2. **NPP Settings** (`settings-only`) -- extract settings zip only, no install
3. **Install NPP** (`install-only`) -- install only, no settings

Settings source: `scripts/33-install-notepadpp/settings/notepadpp-settings.zip`
Settings target: `%APPDATA%\Notepad++\` (full replace, not merge)

Keywords: `npp`, `npp+settings`, `npp-settings`, `install-npp`, `notepad++`, `notepadpp`
Mode resolution: `-Mode` param > `$env:NPP_MODE` > default `install+settings`
