# Issues Log -- VS Code Settings Sync

## Issue 1: Duplicate logging functions across scripts

**Symptom:**
Both script 01 and script 02 defined their own copies of `Write-Log`, `Write-Banner`, `Initialize-Logging`, and `Import-JsonConfig`. Any fix or improvement had to be applied in two places.

**Root cause:**
The helpers were written inline in each script with no shared module. As the project grew to two scripts, the duplication became a maintenance burden and a source of inconsistency.

**Fix:**
Extracted all four functions into `scripts/shared/logging.ps1`. Each script now dot-sources the shared file:

```powershell
$sharedLogging = Join-Path $PSScriptRoot "..\shared\logging.ps1"
. $sharedLogging
```

Script 01's `helpers/logging.ps1` became a thin shim that forwards to the shared file. Script 02 had ~70 lines of inline duplicates removed entirely.

**How to write better code:**
- Start with a shared helpers folder from day one, even if there is only one script. The cost is near zero and it prevents duplication as the project grows.
- If two scripts share any function, extract it immediately -- don't wait for a third.

---

## Issue 2: `ConvertFrom-Json` returns PSCustomObject, not Hashtable

**Quirk (not a crash, but a gotcha):**
`ConvertFrom-Json` in PowerShell 5.1 returns `[PSCustomObject]`, not `[hashtable]`. The `Merge-JsonDeep` function expects hashtables, so a raw `ConvertFrom-Json` result cannot be passed directly.

**Mitigation already in place:**
The script includes `ConvertTo-OrderedHashtable` to bridge the gap. It recursively converts a `PSCustomObject` into an `[ordered]@{}` hashtable before merging.

**How to write better code:**
- In PowerShell 7+ you can use `ConvertFrom-Json -AsHashtable`. Since this project targets 5.1, the converter is necessary -- but document the reason so future contributors don't remove it thinking it is redundant.
- Always add a comment above compatibility shims explaining which PS version requires them.

---

## Issue 3: Profile parsing assumes specific JSON wrapper structure

**Quirk:**
VS Code `.code-profile` exports wrap settings and keybindings in a double-encoded JSON string. The script does:

```powershell
$settingsWrapper = $profileData.settings | ConvertFrom-Json
$settingsContent = $settingsWrapper.settings
```

If VS Code changes this internal format, parsing silently breaks and falls back to individual JSON files. The user may not notice they are running stale settings.

**Mitigation already in place:**
The fallback mechanism logs `"Failed to parse profile"` and proceeds with individual files. However, no explicit warning says "you may be using outdated source files."

**How to write better code:**
- After a profile parse failure and fallback, log a prominent warning: `"Profile parse failed -- using individual JSON files which may be outdated."`
- Add a version check or schema validation for the `.code-profile` format if VS Code documents it.

---

## Issue 4: Extension install errors are silently swallowed

**Quirk:**
`Install-Extensions` catches exceptions per extension, but the VS Code CLI often writes errors to stdout (not stderr) and returns exit code 0 even on partial failure. The `try/catch` may not trigger at all.

```powershell
$output = & $CliCommand --install-extension $ext --force 2>&1
# $LASTEXITCODE is never checked
```

**How to write better code:**
- Check `$LASTEXITCODE` after each CLI call, not just rely on exceptions.
- Parse `$output` for known error patterns like `"Failed"` or `"not found"`.
- Example fix:
  ```powershell
  $output = & $CliCommand --install-extension $ext --force 2>&1
  if ($LASTEXITCODE -ne 0 -or $output -match 'Failed|error') {
      Write-Log "Extension install may have failed: $ext -- $output" "warn"
      $allOk = $false
  }
  ```

---

## Issue 5: No git-pull skip when called from root dispatcher

**Quirk:**
Script 01 checks `$env:SCRIPTS_ROOT_RUN` to skip git pull when launched from the root `run.ps1` dispatcher. Script 02 does **not** check this variable -- it always runs git pull, resulting in a redundant pull when called via the dispatcher.

**How to write better code:**
- Wrap the git-pull block in the same guard used by script 01:
  ```powershell
  if (-not $env:SCRIPTS_ROOT_RUN) {
      # git pull logic
  }
  ```
- Better yet, move the guard into the shared `Invoke-GitPull` function itself so every script gets it for free.
