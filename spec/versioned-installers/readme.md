# Versioned Installers (Pin-on-Release)

**Status**: Approved -- 2026-04-20
**Ships in**: v0.44.0
**Owner**: install-bootstrap + release-pipeline

## Why

Until now, `install.ps1` and `install.sh` always tried to **discover and redirect to the newest published `scripts-fixer-vN` repo**. That is the right behavior for the canonical one-liner, but it breaks **reproducibility from a GitHub Release page**:

> If a user copy-pastes the installer attached to release `v0.41.0`, they expect to get **v0.41.0**, not whatever happens to be the latest at the time they run it.

This spec defines a **version-pinned variant** of the installers that the release pipeline emits as Release assets, alongside the existing source ZIP.

## User-facing flow

On every GitHub Release (`vX.Y.Z`), three artifacts are attached:

| Artifact                                | Purpose                                          |
| --------------------------------------- | ------------------------------------------------ |
| `dev-tools-setup-vX.Y.Z.zip`            | Source ZIP (existing).                           |
| `dev-tools-setup-vX.Y.Z.zip.sha256`     | Checksum (existing).                             |
| **`install-vX.Y.Z.ps1`** *(new)*        | Windows installer pinned to tag `vX.Y.Z`.        |
| **`install-vX.Y.Z.sh`** *(new)*         | Unix installer pinned to tag `vX.Y.Z`.          |

A user copying the snippet from the release page runs:

```powershell
# Windows -- pinned, no discovery, no upgrade
irm https://github.com/<owner>/scripts-fixer-v8/releases/download/v0.43.0/install-v0.43.0.ps1 | iex
```

```bash
# Unix/macOS -- pinned, no discovery, no upgrade
curl -fsSL https://github.com/<owner>/scripts-fixer-v8/releases/download/v0.43.0/install-v0.43.0.sh | bash
```

That installer **always** clones tag `v0.43.0` from the repo it was published against. Auto-discovery is **off**. The probe loop never runs. The user gets exactly the version they asked for, byte-for-byte.

The existing rolling one-liner (`install.ps1` from `main`) keeps its current discovery behavior -- nothing changes there.

## Mechanism

### 1. Pin slot in `install.ps1`

Near the top of `install.ps1` (in the configuration block):

```powershell
# When non-empty, this installer pins to that exact git tag and SKIPS auto-discovery.
# Empty in main = rolling installer (current behavior).
# The release pipeline rewrites this string when it builds install-vX.Y.Z.ps1.
$pinnedVersion = ""
```

Behavior added to the parameter handler:

```powershell
param([switch]$NoUpgrade, [switch]$Version, [string]$Pin)
# CLI flag wins over the baked-in pin so users can override on the command line.
if ($Pin) { $pinnedVersion = $Pin }
```

When `$pinnedVersion` is set:

- Print: `[PIN] Pinned to v<X.Y.Z> -- discovery disabled.`
- Skip the entire probe / redirect block.
- Use `git clone --branch v<X.Y.Z> --depth 1 $repo $folder` instead of `git clone --quiet $repo $folder`.
- The footer line printed by the project's logging layer continues to show `scripts-fixer v<X.Y.Z>` -- consistent with v0.43.0.

### 2. Pin slot in `install.sh`

Same idea, near the top:

```bash
# When non-empty, this installer pins to that exact git tag and SKIPS auto-discovery.
PINNED_VERSION=""
```

CLI flag override:

```bash
for arg in "$@"; do
    case "$arg" in
        --pin) shift; PINNED_VERSION="$1"; shift ;;
        --pin=*) PINNED_VERSION="${arg#*=}" ;;
        ...
    esac
done
```

`git clone` becomes:

```bash
git clone --branch "v$PINNED_VERSION" --depth 1 "$REPO" "$FOLDER"
```

### 3. Release-time generation

In `.github/workflows/release.yml`, **after** "Build release ZIP" and **before** "Publish GitHub Release", add a new step `Build versioned installers`:

```yaml
- name: Build versioned installers
  shell: pwsh
  run: |
      $version    = '${{ steps.resolve.outputs.version }}'
      $outDir     = '.release'
      $psSrc      = 'install.ps1'
      $shSrc      = 'install.sh'
      $psOut      = Join-Path $outDir "install-v$version.ps1"
      $shOut      = Join-Path $outDir "install-v$version.sh"

      foreach ($p in @($psSrc, $shSrc)) {
          if (-not (Test-Path $p)) {
              Write-Host "::error file=$p::Source installer missing -- cannot build pinned variant"
              exit 1
          }
      }

      # PowerShell installer -- replace the pin slot
      $ps = Get-Content $psSrc -Raw
      $psPinned = $ps -replace '(\$pinnedVersion\s*=\s*)""', ('$1"' + $version + '"')
      Set-Content -Path $psOut -Value $psPinned -Encoding UTF8 -NoNewline
      Write-Host "Built $psOut (pinned to v$version)"

      # Bash installer -- replace the pin slot
      $sh = Get-Content $shSrc -Raw
      $shPinned = $sh -replace '(PINNED_VERSION=)""', ('$1"' + $version + '"')
      Set-Content -Path $shOut -Value $shPinned -Encoding UTF8 -NoNewline
      Write-Host "Built $shOut (pinned to v$version)"

      # Sanity check: both files must now contain the version string.
      foreach ($f in @($psOut, $shOut)) {
          $content = Get-Content $f -Raw
          if ($content -notmatch [regex]::Escape($version)) {
              Write-Host "::error file=$f::Pin substitution failed -- file does not contain v$version"
              exit 1
          }
      }
```

Then in the `Publish GitHub Release` step, extend the `files:` block:

```yaml
files: |
    ${{ steps.artifact.outputs.path }}
    ${{ steps.checksum.outputs.path }}
    .release/install-v${{ steps.resolve.outputs.version }}.ps1
    .release/install-v${{ steps.resolve.outputs.version }}.sh
```

### 4. Same-repo install (no cross-version probe)

A pinned installer must clone from the **`-vN` repo it was published from**, not redirect to a newer one. Since the pin disables discovery, this falls out for free -- the existing `$repo = "https://github.com/$owner/$baseName-v$current.git"` resolution is reused, with `--branch v<X.Y.Z>` added.

If the pinned tag does not exist in the target repo (e.g. tag was deleted, or someone is running a pinned installer against a future repo move), `git clone` fails loudly with the standard `[ERROR] Clone failed` block -- no silent fallback to `main`. CODE RED message includes both the repo URL and the missing tag.

## CLI surface (additions)

| Flag (PowerShell)   | Flag (Bash)         | Effect                                                            |
| ------------------- | ------------------- | ----------------------------------------------------------------- |
| `-Pin <X.Y.Z>`      | `--pin <X.Y.Z>`     | Override pin at runtime (works on rolling installer too).         |
| (baked in)          | (baked in)          | When `$pinnedVersion` / `PINNED_VERSION` is non-empty, pin wins. |

`-Version` / `--version`, `-NoUpgrade` / `--no-upgrade`, `-DryRun` / `--dry-run` are unchanged.

When pinned, `-Version` / `--version` prints:

```
[PIN] Pinned to v0.43.0 -- discovery disabled.
[OK]  Will clone tag v0.43.0 from <repo>.
```

## Reproducibility guarantees

A pinned installer downloaded from the v0.43.0 release page will, every time it is run:

1. Clone the **exact** git tag `v0.43.0` from the repo it was published against.
2. Skip the auto-discovery probe entirely.
3. Skip the cross-`-vN`-repo redirect entirely.
4. Print `[PIN] Pinned to v0.43.0` so the user sees the pinned version up front.
5. Result in `scripts/version.json` reading `"version": "0.43.0"`, which the v0.43.0 footer prints on every script run.

If any of these break, the bug is in the installer -- not in the user's environment.

## Out of scope (for v0.44.0)

- Auto-pinning the rolling `install.ps1` / `install.sh` on `main` (intentionally still rolling).
- Signing the pinned installers (future spec).
- Mirroring pinned installers to non-GitHub CDNs.
- A `--pin latest` shorthand (use the rolling installer instead).

## Verification checklist

- [ ] `install.ps1` has `$pinnedVersion = ""` near the top and a `-Pin` parameter.
- [ ] `install.sh` has `PINNED_VERSION=""` near the top and a `--pin` flag.
- [ ] When pinned, both installers print `[PIN]` and skip the `[SCAN]` block.
- [ ] When pinned, both use `git clone --branch v<X.Y.Z> --depth 1`.
- [ ] Release workflow emits `install-vX.Y.Z.ps1` and `install-vX.Y.Z.sh` as release assets.
- [ ] Pin substitution failure aborts the release (`::error` annotation).
- [ ] Rolling installers on `main` still discover newer `-vN` repos as before.
- [ ] `-Pin <X.Y.Z>` / `--pin <X.Y.Z>` CLI override works on the rolling installer too.
