# iOS Build, Signing & Three-iPhone Test

## 1. Current status

The iOS target **exists in source** and uses Apple **MultipeerConnectivity** for the native
byte transport. It shares the entire Flutter application, crypto, relay, SQLite, intelligence,
map and UI layers with Android.

**No IPA was built or tested on this machine.** The development host is Windows; Xcode and the
iOS toolchain are macOS-only. `flutter analyze` and the 41 Dart tests pass, but the Swift
transport has not been compiler-validated here. Build it on macOS before claiming iOS
hardware functionality.

**Cross-platform limitation:** Android Nearby Connections and iOS MultipeerConnectivity do
not discover or talk to each other. A mesh must be **all Android or all iPhone**. There is no
Android↔iOS P2P bridge in this build.

## 2. What is implemented

- `ios/Runner/AppDelegate.swift`
  - registers the existing MethodChannel/EventChannel contract
    (`com.resqmesh/nearby`, `com.resqmesh/nearby/events`);
  - advertises and browses with service type `resqmesh-mesh`;
  - auto-invites discovered peers when auto-connect is enabled;
  - accepts invitations, maintains one `MCSession`, sends reliable byte frames;
  - emits the same `peerFound`, `peerLost`, `connected`, `disconnected`, `payload`,
    `status` and `error` events as Android;
  - contains **no** relay, trust, dedupe, expiry or persistence logic.
- `ios/Runner/Info.plist`
  - `NSLocalNetworkUsageDescription`;
  - `NSBonjourServices` for `_resqmesh-mesh._tcp` and `_resqmesh-mesh._udp`;
  - Bluetooth and location usage descriptions.
- iOS app icon set and navy launch-screen background.
- The Dart permission screen is platform-aware: iOS requests location; Bluetooth and Local
  Network prompts are triggered when the mesh starts.

## 3. Prerequisites

- macOS 13+ (tested Xcode versions may require a recent macOS)
- Xcode 15+ with an iOS SDK
- Flutter 3.47.7+ stable
- An Apple Developer account for device signing (free account works for local devices)
- Three physical iPhones for a real mesh test (simulators are not a substitute for radio testing)
- CocoaPods, if the generated Flutter project uses the CocoaPods fallback

## 4. Build

```bash
cd /path/to/ResQMesh
flutter pub get
flutter analyze
flutter test

# If ios/Podfile exists:
cd ios
pod install --repo-update
cd ..
```

Open the workspace in Xcode:

```bash
open ios/Runner.xcworkspace
```

In Xcode:

1. Select **Runner → Signing & Capabilities**.
2. Choose your Team.
3. Replace `com.resqmesh.resqmesh` with a bundle identifier you own if needed.
4. Confirm deployment target **iOS 15.0**.
5. Connect a physical iPhone, enable Developer Mode, select it as the run destination.
6. Run.

Command-line device run:

```bash
flutter devices
flutter run -d <iphone-device-id>
```

Release build:

```bash
flutter build ios --release --no-codesign   # compile without signing
flutter build ipa --release                  # requires configured signing
```

The IPA path is printed by `flutter build ipa` (usually
`build/ios/ipa/*.ipa`).

## 5. Signing

- Set `PRODUCT_BUNDLE_IDENTIFIER` in Xcode to a unique identifier.
- Select a signing team and let Xcode create/manage provisioning.
- For TestFlight/App Store, create an App Store Connect record, archive in Xcode
  (`Product → Archive`), and upload.
- Do not commit provisioning profiles, certificates or `ExportOptions.plist` with secrets.

## 6. iOS permissions

iOS prompts separately for location and Local Network. The app **will not discover peers** if
Local Network access is denied.

- Allow **Local Network** when starting the mesh.
- Allow **Precise Location** for SOS/hazard coordinates.
- Allow Bluetooth if iOS prompts.
- Verify in **Settings → Privacy & Security → Local Network → ResQMesh**.
- Verify location in **Settings → Privacy & Security → Location Services → ResQMesh**.

Bonjour service type must match exactly:

```text
resqmesh-mesh
_resqmesh-mesh._tcp
_resqmesh-mesh._udp
```

## 7. Three-iPhone test

1. Build the same app version on all three iPhones.
2. Open ResQMesh, complete onboarding, and set the **same mesh network key** on all three.
3. Disable mobile data and Wi-Fi internet; keep Wi-Fi and Bluetooth radios on.
4. Start **More → Nearby Mesh Devices → Start mesh**.
5. Accept the **Local Network** prompt on each phone.
6. Wait until peers appear. Put B between A and C; A and C should be out of direct range for a
   true multi-hop proof.
7. A sends the SOS; B stores/relays; C confirms the incident and sends the receipt.
8. A shows **Receipt confirmed**; B's black box shows `message_forwarded`; C's inbox shows the
   incident.

Expected caveats:

- Acknowledgement is best-effort, not a rescue guarantee.
- iOS may suspend the app in the background; keep it foreground.
- MultipeerConnectivity may use Wi-Fi/Bluetooth; it does not require an internet connection.
- iOS to Android will not appear in discovery.

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| No local network prompt | Delete/reinstall the app, reset Local Network privacy, or check Settings → Privacy & Security → Local Network. |
| Peers never appear | Confirm all phones are iPhones, same build, same service type, Bluetooth/Wi-Fi on, and app foreground. |
| `NSBonjourServices` warning | Ensure both `_resqmesh-mesh._tcp` and `_resqmesh-mesh._udp` are in Info.plist. |
| Invitation never connects | Move devices closer, restart mesh on all phones, check Local Network permission. |
| Build fails on Windows | iOS builds require macOS/Xcode. Use the existing Android APK for Android testing. |
| Signing error | Select a valid Team and unique bundle ID in Xcode; check the provisioning profile. |
| Duplicate peer names | Device names should be unique; set distinct names in Settings. MultipeerConnectivity uses display names. |

## 9. Security / privacy notes

- MCSession is configured with `.required` encryption, and the app envelope additionally uses
  Ed25519 signatures and AES-256-GCM group encryption.
- TOFU pinning, TTL, dedupe, rate limits and the black box apply identically on iOS.
- Shared group passphrase limitations are the same as Android; see
  [`SECURITY_AND_LIMITATIONS.md`](SECURITY_AND_LIMITATIONS.md).
- iOS Keychain-backed secure storage is used by `flutter_secure_storage`.
- The iOS app is foreground-only in this build (no `BGTask`/background mesh service).

## 10. What was not verified here

- Swift compilation under Xcode.
- iOS Local Network discovery on hardware.
- Three-iPhone relay, acknowledgement and callbacks.
- Battery/thermal behaviour and App Store review.

Do not report iOS hardware success until this guide has been executed on physical iPhones.