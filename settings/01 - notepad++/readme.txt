export or unzip to "%appdata%" or "C:\Users\{user}\AppData\Roaming"

To export your current Notepad++ settings to this folder:
  .\run.ps1 -I 33 -- export

This copies config files (.xml, .json, .ini) and folders (themes,
userDefineLangs) from %APPDATA%\Notepad++\ into this folder.
Runtime folders (backup, session, plugins) and files > 512 KB are skipped.

Usage:
  .\run.ps1 install npp              # Install NPP + sync settings
  .\run.ps1 install npp-settings     # Sync settings only
  .\run.ps1 -I 33 -- export         # Export settings from machine to repo
