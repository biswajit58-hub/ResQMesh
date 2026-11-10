# Windows + VS Code Setup

## 1. Prerequisites

| Tool | Recommended / tested |
|---|---|
| Windows | 10/11 x64 |
| Flutter SDK | 3.47.7 stable (tested), bundled Dart 3.13.5 |
| Android Studio | Latest with Android SDK, platform-tools, emulator |
| JDK | Android Studio JBR (JDK 17/21); tested with JBR 17 |
| Git for Windows | Required by Flutter; recent version on PATH |
| VS Code | Latest with Flutter + Dart extensions |
| Android device | Android 7.0+ (minSdk 24), Google Play services, Bluetooth + Wi-Fi |

**Nearby Connections requires Google Play services.** AOSP / de-Googled devices or some
emulators will correctly show “Nearby radio unavailable”; local SOS, demo mode and protocol
lab still work.

**iOS is not buildable on this Windows host.** The iOS source is included, but Xcode/macOS is
required. See [`IOS_BUILD.md`](IOS_BUILD.md).

## 2. Install Flutter

```powershell
git clone https://github.com/flutter/flutter.git -b stable C:\flutter
[Environment]::SetEnvironmentVariable("Path", "C:\flutter\bin;" + $env:Path, "User")
flutter --version
flutter doctor -v
```

Accept Android licences:

```powershell
flutter doctor --android-licenses
```

If Flutter reports missing Git, install Git for Windows and ensure `git --version` works in a
new terminal. If it reports Android cmdline-tools missing, use **Android Studio → SDK
Manager → SDK Tools → Android SDK Command-line Tools**.

## 3. Configure Android Studio / SDK

1. **SDK Manager** install:
   - Android SDK Platform (API 36 or the version Flutter requests)
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
   - Android SDK Command-line Tools
   - Android Emulator (optional) and an x86_64 Google APIs/Play image
2. **Device Manager** create an emulator with at least 4 GB RAM and hardware acceleration.
3. Use the embedded JDK: **Settings → Build, Execution, Deployment → Build Tools → Gradle →
   Gradle JDK = jbr-17/21**.

Environment variables (adjust paths):

```powershell
setx ANDROID_HOME "$env:LOCALAPPDATA\Android\Sdk"
setx ANDROID_SDK_ROOT "$env:LOCALAPPDATA\Android\Sdk"
setx JAVA_HOME "C:\Program Files\Android\Android Studio\jbr"
```

Close and reopen VS Code after changing environment variables.

## 4. VS Code setup

Extensions:

- **Flutter** (`Dart-Code.flutter`)
- **Dart** (`Dart-Code.dart-code`)
- Optional: **Kotlin**, **Android iOS Emulator**, **Error Lens**

Useful `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "ResQMesh (debug)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart"
    }
  ]
}
```

Open the project folder and run:

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

For a physical phone, enable **Developer options → USB debugging**, connect by USB, authorize
the RSA prompt, and confirm `adb devices` shows `device` (not `unauthorized`).

## 5. Build the APK

```powershell
flutter build apk --debug
# build\app\outputs\flutter-apk\app-debug.apk

adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Install on each field-test phone. Detailed signing and release notes:
[`APK_BUILD.md`](APK_BUILD.md).

## 6. Recommended device settings for field tests

- Disable mobile data and Wi-Fi **internet**; keep Bluetooth and Wi-Fi radios on.
- Grant **Precise location**, **Nearby devices**, and Android 12+ **Bluetooth scan/connect/
  advertise** and Android 13+ **Nearby Wi-Fi devices**.
- Disable battery optimization for ResQMesh during the test.
- Keep the app in the foreground. This build does not include a foreground service.
- Set the same **mesh network key** on every phone (Settings → Mesh network key). The default
  key is public; change it before field use.

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| `git` not found while Flutter works | Add `C:\flutter\bin\mingit\cmd` (or Git for Windows `cmd`) to PATH, restart terminal. |
| `Unable to locate Android SDK` | Set `ANDROID_HOME`/`ANDROID_SDK_ROOT`; run `flutter config --android-sdk <path>`. |
| Gradle download stalls | Check network/proxy; retry; Gradle cache is under `%USERPROFILE%\.gradle`. |
| `Nearby radio unavailable` | Install/update Google Play services; use a supported physical device. Emulators often cannot run real Nearby. |
| Mesh won't start | Grant all nearby permissions; check native error in the app diagnostics or `adb logcat`. |
| No peers found | Keep both phones' screens on; Bluetooth and Wi-Fi on; move closer; restart mesh on both; check same app/service build. |
| GPS unavailable | Use **Enter coordinates** on the SOS screen; last-known location remains labelled with its timestamp. |
| Emulator gets “System UI isn't responding” | Give the emulator ≥4 GB RAM and hardware acceleration; physical devices are strongly preferred. |
| Build fails with resource shrinking | Already worked around in `android/app/build.gradle.kts` with `isShrinkResources = false` for AGP 9. |
| Old app data conflicts with testing | Uninstall/reinstall the APK; this clears the local SQLite and secure identity. |

## 8. Useful diagnostics

```powershell
flutter doctor -v
flutter analyze
flutter test --reporter expanded
adb devices -l
adb logcat -s flutter
adb shell am force-stop com.resqmesh.resqmesh
adb shell monkey -p com.resqmesh.resqmesh -c android.intent.category.LAUNCHER 1
```

In-app diagnostics: **More → Settings → Diagnostics** and **Disaster black box**.
