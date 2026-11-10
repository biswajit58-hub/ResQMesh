# Test Results

**Environment:** Windows, Flutter 3.47.7 stable, Dart 3.13.5, sqflite FFI for database tests,
Android emulator API 37 (visual verification only).

## 1. Static analysis

```powershell
flutter analyze
```

Result:

```text
No issues found!
```

## 2. Automated tests

```powershell
flutter test --reporter expanded
```

Result: **41 tests passed, 0 failed.**

Tests are configured to run sequentially (`dart_test.yaml: concurrency: 1`) because the relay
integration test intentionally opens three SQLite databases and asynchronous mesh services;
sequential execution makes teardown deterministic.

| Test file | Tests | What is verified |
|---|---:|---|
| `test/mesh_crypto_test.dart` | 9 | Ed25519 identity binding, seal/open, tamper rejection, wrong group key, expiry, hop forwarding, malformed/oversized frames, wire round-trip |
| `test/relay_integration_test.dart` | 2 | Real `MeshService` with A—B—C fake byte transport: SOS relay, C→B→A authenticated receipt, duplicate replay rejection, forwarded-frame audit, forged origin identity rejected |
| `test/verification_test.dart` | 10 | Unverified, same-origin forwarding not independent, distance/window/category corroboration, responder verification, disputes, disputed-report exclusion, self-verification prevention, demo/real isolation, expiry |
| `test/intelligence_priority_test.dart` | 4 | Hazard clustering, factor explainability, same-origin non-independence, priority ordering, proximity availability, factor coverage |
| `test/evacuation_test.dart` | 5 | A* route around a blocking flood, no-hazard warning, no-shelter failure, shelter ranking, disputed hazard warning |
| `test/database_test.dart` | 5 | Schema/CRUD, demo isolation and demo clear preserving real rows, duplicate lookup/status, shelters/votes, audit append/read |
| `test/protocol_and_localization_test.dart` | 3 | Protocol lab adversarial checks, settings JSON across locales, English/Hindi/Odia strings |
| `test/widget_smoke_test.dart` | 2 | SOS button tap/accessibility smoke, brand/status/empty components |
| `test/sos_screen_test.dart` | 1 | SOS form renders with demo/offline fallback and exposes manual coordinates |

### Relay integration evidence

The integration test uses the production `MeshService`, real crypto, real SQLite and a fake
transport that only moves opaque bytes. It asserts:

- C stores A's incident after one relay;
- B's stored copy has hop 0, C's has hop 1;
- A's message status becomes `acknowledged` after C's receipt traverses B;
- A's incident receipt count increments;
- B's audit log contains `message_forwarded`;
- replaying C's exact forwarded frame logs `duplicate_dropped` and does not create a second
  incident;
- a frame with a forged `originId` is rejected and not stored.

This proves the relay state machine. It is **not** a physical radio test.

## 3. APK build

```powershell
flutter build apk --debug
```

Observed:

```text
Running Gradle task 'assembleDebug'...
✓ Built build\app\outputs\flutter-apk\app-debug.apk

Running Gradle task 'assembleRelease'...
✓ Built build\app\outputs\flutter-apk\app-release.apk (61.0MB)
```

The final build completed with exit code 0 and produced both debug and release APKs. Flutter
still prints Kotlin-plugin future-migration warnings (see `docs/APK_BUILD.md`).

Kotlin Nearby plugin compiled successfully after fixing the Flutter embedding `FlutterPlugin`
import. AGP 9 initially rejected implicit resource shrinking; `isShrinkResources = false` was
set for debug/release alongside `isMinifyEnabled = false`.

## 4. Manual emulator verification

Android emulator (API 37, Google Play image) was used for visual/runtime checks. The emulator
itself was unstable under software rendering (Android System UI binder exhaustion / ANR), which
is an emulator environment issue, not an app crash.

Verified screens:

- splash and animated onboarding;
- permission setup screen (location + Nearby permissions; skip path);
- dark navy home dashboard with SOS button, status pills, metric tiles, incident card;
- feature hub (12 destinations);
- demo lab selection and successful Flood scenario activation;
- demo home with DEMO banner/badges, 8 seeded incidents, 2 active SOS, 4 open shelters,
  simulated node count and priority scores;
- app relaunch restored demo mode and synthetic data (after lazy-tab and
  demo-reseed-skip improvements, startup no longer builds the hidden map tab).

Not fully exercised on the emulator before it became unstable: live map panning/tiles,
SOS form submission, Protocol Lab run, responder session, black-box export. These paths are
covered by unit/integration tests where applicable; hardware validation remains required.

## 4.1 Map 403 fix verification

The map originally used the public OSM tile endpoint directly. Some networks/devices return
HTTP 403 "access blocked" from that endpoint. The fix:

- CARTO dark basemap (`{s}.basemaps.cartocdn.com/dark_all/...`) is now the primary source;
- OSM remains a secondary fallback with an application User-Agent;
- any 403/non-image response falls through to the next provider;
- if both providers fail, a generated offline grid tile is rendered;
- one failed provider no longer disables the whole map for several minutes;
- attribution now includes OpenStreetMap and CARTO.

Endpoint check from the build machine:

```text
CARTO  HTTP 200, image/png (2,513 bytes)
OSM    HTTP 200, image/png (10,907 bytes)
```

`flutter analyze` clean and all 41 tests pass after the fix.
## 5. Real three-device test

**Not performed.** The development environment did not expose three physical Android phones or
three iPhones. Do not claim a physical A→B→C relay from this build environment.

A complete hardware procedure is in
[`FIELD_TEST_3_DEVICE.md`](FIELD_TEST_3_DEVICE.md). The in-app Protocol Lab is explicitly
labelled as an in-memory simulation, and the automated integration test is labelled as a
fake-transport test.

## 6. Reproduce

```powershell
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
```

For a single relay test:

```powershell
flutter test test/relay_integration_test.dart --reporter expanded
```

## 7. iOS target status

The iOS platform (`ios/`) and Swift MultipeerConnectivity transport are present. `flutter
analyze` remains clean after the platform-aware Dart changes, and all 41 Dart tests still pass.

The iOS app was **not compiled** and no IPA was produced: this host is Windows and has neither
Xcode nor a Swift toolchain (`swift`/`xcodebuild` are unavailable). The Swift source parses
cleanly with a tree-sitter Swift grammar (no syntax errors), but it has not been type-checked,
linked or hardware-validated. See [`IOS_BUILD.md`](IOS_BUILD.md).

Android and iOS use different native transports and cannot form a mixed mesh.
