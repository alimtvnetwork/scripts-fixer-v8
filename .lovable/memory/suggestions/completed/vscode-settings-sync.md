# Suggestions: VS Code Profile Importer (Script 02)

## Potential Improvements

### 1. Dry-Run Mode (`-DryRun` switch)
Show what would be applied (settings diff, extensions to install, keybindings changes) without writing any files or installing anything. Useful for reviewing before committing.

### 2. Merge Mode (`-Merge` switch)
Instead of backup & replace, deep-merge the new settings into the existing `settings.json`. This preserves user-specific tweaks while layering in the profile's values. Conflicts could default to the profile's value with a `-PreferExisting` override.

### 3. Disable Extensions Support
The `extensions.json` already tracks a `disabled` list. Add a step that explicitly disables those extensions via `code --disable-extension <id>` after installing, ensuring the profile's disabled state is fully replicated.

### 4. Profile Export (Reverse Direction)
Add an `-Export` switch that reads the current VS Code settings, keybindings, and installed extensions, then generates a `.code-profile` file or updates the individual JSON files in the script folder. Makes it easy to capture a working setup.

### 5. Extension Version Pinning
Record and install specific extension versions (`publisher.name@version`) for reproducible environments, especially useful in team setups where extension updates can break workflows.

### 6. Selective Apply (`-Only` parameter)
Allow applying only specific parts of the profile:
```powershell
.\run.ps1 -I 2 -Only settings
.\run.ps1 -I 2 -Only extensions
.\run.ps1 -I 2 -Only keybindings
```

### 7. Edition Targeting Override
Allow overriding `enabledEditions` from the command line without editing `config.json`:
```powershell
.\run.ps1 -I 2 -Edition insiders
```

### 8. Diff Preview
Before applying, show a side-by-side or unified diff of current vs. incoming settings using `Compare-Object`, so the user knows exactly what changes.

### 9. Rollback Support
Track the latest backup path and add a `-Rollback` switch to restore the previous settings and keybindings in one command.

### 10. Snippet Support
VS Code profiles can include custom snippets. Parse and deploy snippet files from the profile into the `snippets/` subdirectory of the user settings path.
