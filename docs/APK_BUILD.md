# Android APK Build & Install

> This guide covers Android only. For the iOS target and Xcode signing, see
> [`IOS_BUILD.md`](IOS_BUILD.md). Android and iOS meshes do not interoperate.

## 1. Build a debug APK

From the project root on Windows PowerShell:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Artifacts (also copied to `dist/`):

```text
build\app\outputs\flutter-apk\app-debug.apk
dist\resqmesh-debug.apk
```

The debug APK is large (native debug symbols + all ABIs). It is signed with the local debug
key and installs directly:

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## 2. Build a release APK (hackathon distribution)

The current `android/app/build.gradle.kts` signs **release** with the debug key so that
`flutter run --release` and a locally installable hackathon APK work out of the box:

```powershell
flutter build apk --release
# build\app\outputs\flutter-apk\app-release.apk  (61.0 MB in the tested build)
# dist\resqmesh-release.apk
```

Verify the distributed files:

```powershell
Get-FileHash dist\resqmesh-release.apk -Algorithm SHA256
Get-Content dist\SHA256SUMS.txt
```

> Replace the debug signing config with a private keystore before distributing publicly.
> Never ship a production emergency app with a debug key.

### Custom release keystore

```powershell
keytool -genkeypair -v -keystore resqmesh-release.jks -keyalg RSA -keysize 4096 `
  -validity 10000 -alias resqmesh
```

Create `android/key.properties` (do not commit):

```properties
storePassword=...
keyPassword=...
keyAlias=resqmesh
storeFile=C:/secure/resqmesh-release.jks
```

Then update the `signingConfigs`/`buildTypes` block to load those values. See Flutter's
official “Build and release an Android app” guide.

## 3. Split ABI APKs (smaller)

```powershell
flutter build apk --split-per-abi
```

Outputs per ABI under `build\app\outputs\flutter-apk\`. Use `app-arm64-v8a-release.apk` for
most modern phones.

## 4. Android configuration in this project

| Setting | Value |
|---|---|
| Application ID | `com.resqmesh.resqmesh` |
| minSdk | 24 |
| compileSdk/targetSdk | Flutter defaults (API 36 in tested toolchain) |
| Kotlin | 2.4.0, JVM target 17 |
| AGP | 9.1.0 |
| Nearby dependency | `com.google.android.gms:play-services-nearby:19.3.0` |
| Manifest permissions | location, Bluetooth scan/connect/advertise, Nearby Wi-Fi devices, Wi-Fi state, internet (map tiles only), vibrate |
| Backup | Disabled (`allowBackup=false`) for emergency data |
| Cleartext | Disabled; CARTO/OSM tiles use HTTPS |
| Resource shrinking | Disabled together with minification (AGP 9 workaround) |
| Foreground service | Not included |

## 5. Verify the build

```powershell
Get-FileHash build\app\outputs\flutter-apk\app-debug.apk -Algorithm SHA256
adb shell pm list packages | Select-String resqmesh
adb shell dumpsys package com.resqmesh.resqmesh | Select-String versionName
```

In-app: **More → Settings → Diagnostics** should show version 1.0.0, transport status and
database schema.

## 6. Build-time notes

- First build downloads Gradle, AGP, Kotlin and Play Services; allow several minutes.
- The tested environment built successfully with Flutter 3.47.7 / Gradle 9.3.1 / JDK 17.
- Flutter prints warnings that this template applies the Kotlin Gradle Plugin and that future
  Flutter versions want **Built-in Kotlin**. Current build succeeds; plan a migration.
- If AGP reports “Removing unused resources requires unused code shrinking”, ensure
  `isShrinkResources = false` for both debug and release in `android/app/build.gradle.kts`.
- No backend, API key or PostgreSQL is needed to run the app.

## 7. Install on the three field-test phones

1. Copy/install the same APK build on A, B and C (same signing key, same version).
2. Open the app once and complete onboarding/permissions on each.
3. Set the same mesh network key on each phone.
4. Follow [`FIELD_TEST_3_DEVICE.md`](FIELD_TEST_3_DEVICE.md).
