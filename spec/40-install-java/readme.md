# Spec: Script 40 -- Install Java (OpenJDK)

## Purpose

Install Java (OpenJDK) via Chocolatey with version selection support.
Users can install the latest OpenJDK or a specific LTS version.
Configures JAVA_HOME environment variable automatically.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install Java + set JAVA_HOME + configure PATH (default) |
| `install` | Install Java only |
| `install <version>` | Install a specific OpenJDK version |
| `uninstall` | Uninstall all Java versions, remove JAVA_HOME, clean PATH, purge tracking |
| `-Help` | Show usage information |

## Parameters

| Parameter | Position | Description |
|-----------|----------|-------------|
| `-Path` | 1 (after command) | Custom dev directory path. Overrides `$env:DEV_DIR`. |

## Version Selection

| Version | Choco Package | Description |
|---------|---------------|-------------|
| `latest` | `openjdk` | Newest OpenJDK (default) |
| `17` | `openjdk17` | OpenJDK 17 LTS |
| `21` | `openjdk21` | OpenJDK 21 LTS |

### Usage Examples

```powershell
.\run.ps1 -I 40                    # Install latest OpenJDK
.\run.ps1 -I 40 -- install 21     # Install OpenJDK 21 LTS
.\run.ps1 -I 40 -- install 17     # Install OpenJDK 17 LTS
.\run.ps1 -I 40 -- uninstall      # Full uninstall + cleanup
.\run.ps1 install java             # Via keyword (latest)
.\run.ps1 install openjdk          # Via keyword (latest)
.\run.ps1 install jdk-21           # Via keyword (OpenJDK 21)
.\run.ps1 install jdk-17           # Via keyword (OpenJDK 17)
```

## Uninstall

The `uninstall` subcommand performs a full cleanup:

1. **Chocolatey uninstall** -- removes all OpenJDK packages
2. **JAVA_HOME** -- removes the environment variable from User scope
3. **PATH cleanup** -- removes `<devDir>\java\bin` from User PATH
4. **Dev directory** -- deletes `<devDir>\java` subfolder
5. **Tracking records** -- purges `.installed/java-*.json` and `.resolved/40-install-java/`

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `chocoPackages` | object | Maps version keys to Chocolatey package names |
| `defaultVersion` | string | Version to install when none specified |
| `availableVersions` | array | Valid version keys |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `devDirSubfolder` | string | Subfolder under dev dir |
| `env.setJavaHome` | bool | Whether to set JAVA_HOME env var |
| `path.updateUserPath` | bool | Add java/bin to PATH |

## Flow

1. Assert admin + Chocolatey
2. Log install target directory
3. Resolve requested version (default: latest)
4. Install/upgrade Java via Chocolatey
5. Set JAVA_HOME environment variable
6. Add `<devDir>\java\bin` to User PATH
7. Save resolved state (java -version)

## Install Keywords

| Keyword |
|---------|
| `java` |
| `openjdk` |
| `jdk` |
| `jre` |
| `jdk-17` |
| `jdk-21` |
