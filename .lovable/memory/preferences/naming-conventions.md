---
name: Naming conventions
description: Boolean is/has prefixes; all file/folder names lowercase-hyphenated (kebab-case); markdown files lowercase-hyphenated
type: preference
---
## Boolean Variables
All boolean variables must use `is` or `has` prefix (e.g. `$isDisabled`, `$hasAdminRights`, `$isMissing`).
Instead of `if (-not $foo)`, assign to a named boolean first: `$isFooMissing = -not $foo; if ($isFooMissing)`.

## File & Folder Names
1. All file names use lowercase-hyphenated (kebab-case): `run.ps1`, `log-messages.json`, `config.json`
2. Markdown files follow the same rule: `readme.md`, `changelog.md`, `bump-version.md` — never `README.md` or `CHANGELOG.md`
3. Never use PascalCase or camelCase for file names (e.g. ~~Fix-VSCodeContextMenu.ps1~~)
4. Folder names also use lowercase-hyphenated: `01-install-vscode/`, `model-picker/`
5. PowerShell functions *inside* scripts may still use Verb-Noun PascalCase per PS convention
