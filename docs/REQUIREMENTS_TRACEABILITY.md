# Requirements Traceability

This table maps the requested deliverables to the implementation and records honest status.

| # | Required deliverable | Where | Status |
|---|---|---|---|
| 1 | Complete Flutter source code | `lib/` (83 Dart files) | Complete |
| 2 | Native Android Kotlin networking | `NearbyMeshPlugin.kt`, `MainActivity.kt` | Complete and compiled into APK; physical radio behavior not hardware-tested |
| 2b | Native iOS Swift networking | `ios/Runner/AppDelegate.swift` (MultipeerConnectivity) | Implemented in source; requires macOS/Xcode; not compiled or hardware-tested on this Windows host |
| 3 | Working offline SOS functionality | `features/sos`, `AppState.createSos`, SQLite, MeshCrypto | Implemented; widget-tested form + local queue path. Physical radio test pending |
| 4 | Real peer-to-peer communication | Nearby Connections Kotlin transport + MeshService | Real transport code; automated relay test uses fake byte transport. No real radio claim |
| 5 | Three-device message relay demonstration | `test/relay_integration_test.dart`, in-app Protocol Lab, field-test guide | Automated 3-node proof + clear simulation; physical 3-phone test **not performed** |
| 6 | Offline hazard and shelter map | `OfflineMapView`, `TileCacheService`, `ShelterScreen`, demo shelters | Implemented with cached/generated tiles and uncertainty warnings |
| 7 | Intelligent disaster prioritization | `PriorityService`, `IntelligenceService` | Implemented with transparent factors and missing-input disclosure |
| 8 | Responder dashboard | `ResponderDashboardScreen`, `ResponderService` | Implemented with local PIN gate, triage, status/verification/shelter updates |
| 9 | Digital twin visualization | `DigitalTwinScreen` | Implemented with animated markers, risk circles, time window, honest peer-position note |
| 10 | Local database | `core/database`, SQLite schema v1, FFI tests | Implemented and tested |
| 11 | Test cases and test results | `test/`, `docs/TEST_RESULTS.md` | 41 tests passing; `flutter analyze` clean |
| 12 | Windows and VS Code setup guide | `docs/SETUP_WINDOWS_VSCODE.md` | Complete |
| 12b | iOS build/signing/field guide | `docs/IOS_BUILD.md`, `ios/` | Source complete; no IPA built because Xcode/macOS unavailable |
| 13 | Android APK build instructions | `docs/APK_BUILD.md`, `dist/` | Complete; debug + release APKs built |
| 14 | Architecture documentation | `docs/ARCHITECTURE.md`, `docs/PROTOCOL.md` | Complete |
| 15 | Hackathon presentation and demonstration script | `docs/PRESENTATION_AND_DEMO_SCRIPT.md`, `docs/FIELD_TEST_3_DEVICE.md` | Complete, including honest fallback script |

## Detailed feature traceability

| Requirement | Implementation |
|---|---|
| Self-healing mesh | Discovery, connections, opaque byte transport (Kotlin); relay queue, unique IDs, dedupe, expiry, hop limit, priority, store-and-forward, retry (Dart) |
| Intelligent SOS | Large red SOS control, GPS/manual location, category, severity, people count, UUID, local store, queued/transmitted/acknowledged status |
| AI-assisted hazard intelligence | Rule-based clustering + explainable risk factors; no ML, no fabricated measurements |
| Crowd verification | Unverified / community corroborated / responder verified / disputed / expired; distinct origins only |
| Rescue priority | Severity, people, waiting, reliability, location confidence, proximity; per-factor explanations |
| Offline evacuation | Cached/generated tiles, shelters, hazard buffers, A* advisory route, stale/incomplete warnings |
| Last-known survivor location | Timestamp/source/accuracy preserved; old fixes never labelled live |
| Digital twin | flutter_map situation map, layers, risk circles, animated markers, time window |
| Disaster black box | Append-only SQLite audit + JSON export |
| UI screens | Splash, onboarding, permissions, home, SOS, map, alerts, hazard report, shelter finder, nearby devices, inbox, incident detail, responder, intelligence, digital twin, event history, settings, demo lab, More hub (19 screens/routes) |
| Languages | English, Hindi, Odia core UI; some long technical narratives remain English |
| Platforms | Android 7+ via Nearby Connections; iOS 15+ via MultipeerConnectivity; no Android↔iOS radio interop |
| Security | Ed25519, AES-GCM, TOFU, rate limiting, malformed handling, app-private DB, backup disabled |
| Demo mode | Flood/earthquake/landslide synthetic data, DEMO badges, radios disabled, protocol lab, no demo over real transport |
| Window/VS Code | Environment, SDK, extensions, launch config, troubleshooting |
| APK | `dist/resqmesh-release.apk` (61.0 MB), `dist/resqmesh-debug.apk`, SHA256SUMS |

## Known gaps (explicit)

- No physical three-phone radio demonstration was possible in this environment (Android or iOS).
- iOS source was not compiled or hardware-tested; this Windows host has no Xcode/Swift toolchain.
- No foreground service; keep the app in the foreground.
- No SQLCipher / DB-at-rest encryption.
- Group shared key, not pairwise E2E; TOFU has no revocation UI.
- No backend/PostgreSQL/Next.js dashboard.
- Route guidance is geometric advice over local reports, not a road-network or flood model.
- Core UI localized; long synthetic narratives and some diagnostics remain English.
