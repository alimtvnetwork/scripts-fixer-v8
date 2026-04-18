Windows Terminal Settings
========================

Place your settings.json file here.

Script 37 (install-windows-terminal) handles sync automatically:
1. Finds %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\
2. Copies settings.json to that directory
3. Copies any additional files (themes, fragments) alongside it

Windows Terminal reads settings.json from LocalState on startup.

To export your current Windows Terminal settings to this folder:
  .\run.ps1 -I 37 -- export

This copies settings.json and additional config files from
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\ into this folder.
state.json is excluded (runtime state, not config).
Files larger than 512 KB are skipped.

Usage:
  .\run.ps1 install wt              # Install WT + sync settings
  .\run.ps1 install wt-settings     # Sync settings only
  .\run.ps1 -I 37 -- export        # Export settings from machine to repo
