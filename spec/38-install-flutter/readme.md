# Spec: Script 38 -- Install Flutter

## Purpose

Installs a complete Flutter development environment: Flutter SDK (includes
Dart), Android Studio, Google Chrome (for Flutter web), and VS Code
Flutter/Dart extensions. Runs `flutter doctor` post-install to verify setup.

## Usage

```powershell
.\run.ps1                    # Install everything (default)
.\run.ps1 install            # Install Flutter SDK only
.\run.ps1 android            # Install Android Studio only
.\run.ps1 chrome             # Install Google Chrome only
.\run.ps1 extensions         # Install VS Code Flutter/Dart extensions only
.\run.ps1 doctor             # Run flutter doctor only
.\run.ps1 -Help              # Show usage
```

## What Gets Installed

| Component | Package | Method |
|-----------|---------|--------|
| Flutter SDK | `flutter` | Chocolatey |
| Dart SDK | (bundled) | Included with Flutter |
| Android Studio | `androidstudio` | Chocolatey |
| Google Chrome | `googlechrome` | Chocolatey |
| Dart extension | `Dart-Code.dart-code` | `code --install-extension` |
| Flutter extension | `Dart-Code.flutter` | `code --install-extension` |

## Post-Install

- Accepts Android SDK licenses automatically (`flutter doctor --android-licenses`)
- Runs `flutter doctor` to show environment status

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `flutter.chocoPackageName` | string | Chocolatey package name |
| `flutter.alwaysUpgradeToLatest` | bool | Upgrade if already installed |
| `androidStudio.enabled` | bool | Toggle Android Studio install |
| `androidStudio.chocoPackageName` | string | Chocolatey package name |
| `chrome.enabled` | bool | Toggle Chrome install |
| `chrome.chocoPackageName` | string | Chocolatey package name |
| `vscodeExtensions.enabled` | bool | Toggle VS Code extension install |
| `vscodeExtensions.extensions` | array | Extension IDs to install |
| `postInstall.runFlutterDoctor` | bool | Run flutter doctor after install |
| `postInstall.acceptAndroidLicenses` | bool | Auto-accept Android licenses |

## Install Keywords

| Keyword | Script | Mode |
|---------|--------|------|
| `flutter` | 38 | `install` |
| `dart` | 38 | `install` |
| `mobile` | 38 | `install` |
| `install-flutter` | 38 | `install` |
| `flutter+android` | 38 | `android` |
| `flutter-extensions` | 38 | `extensions` |
| `flutter-doctor` | 38 | `doctor` |
| `mobile-dev` | 38 | (default -- all components) |
| `mobiledev` | 38 | (default -- all components) |

```powershell
.\run.ps1 install flutter            # SDK only
.\run.ps1 install flutter+android    # Android Studio only
.\run.ps1 install flutter-extensions # VS Code extensions only
.\run.ps1 install flutter-doctor     # Run flutter doctor only
.\run.ps1 install mobile-dev         # Full Flutter stack
```

## Helpers

| File | Functions | Purpose |
|------|-----------|---------|
| `flutter.ps1` | `Install-Flutter`, `Install-AndroidStudio`, `Install-Chrome`, `Install-FlutterVscodeExtensions`, `Invoke-FlutterDoctor` | Component installers |

## Resolved State

```json
{
  "flutterVersion": "3.x.x",
  "dartVersion": "Dart SDK version: 3.x.x",
  "channel": "stable",
  "timestamp": "2025-..."
}
```
