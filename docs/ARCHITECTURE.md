# ResQMesh Architecture

## 1. Design goals

1. **Emergency core independent of backend and internet.** SOS creation, persistence,
   encryption, relay, verification, intelligence and evacuation run on-device.
2. **Transport is not the protocol.** The native peer transport (Nearby Connections on
   Android, MultipeerConnectivity on iOS) moves bytes; ResQMesh owns message identity,
   signatures, expiry, dedupe, hop limits, acknowledgements and store-and-forward.
3. **Honest states.** The UI distinguishes local storage, transport send, receipt
   acknowledgement, observed reports and estimated risk. It never claims guaranteed delivery
   or safety.
4. **Modularity and testability.** Pure Dart services hold business logic; SQLite
   repositories own persistence; a narrow MethodChannel/EventChannel boundary isolates Kotlin.
5. **Demo/field isolation.** Synthetic data is tagged end-to-end and cannot be broadcast on a
   real radio transport.

## 2. Layer map

| Layer | Main code | Responsibility |
|---|---|---|
| Presentation | `lib/features/**`, `lib/widgets/**` | 15+ screens, theme, localization, accessible SOS affordance |
| Application state | `lib/services/app_state.dart` | Lifecycle, loading, refresh, actions, demo isolation, responder session, export |
| Domain services | `lib/services/*.dart` | Mesh relay, verification, intelligence, priority, evacuation, demo, audit, protocol simulation |
| Security | `lib/core/security/**` | Device identity, group encryption, TOFU pinning, secure storage |
| Networking | `lib/core/networking/**` | Transport contract, Nearby adapter, payload schemas, rate limiting |
| Persistence | `lib/core/database/**` | SQLite schema and repositories |
| Native transport | `android/.../NearbyMeshPlugin.kt`; `ios/Runner/AppDelegate.swift` | Android Nearby Connections and iOS MultipeerConnectivity discovery, connection lifecycle and byte transfer |
| Localization | `lib/core/localization/**` | English, Hindi, Odia key-value catalogues |
| Mapping | `OfflineMapView`, `TileCacheService`, `ResqTileProvider` | flutter_map, CARTO dark tiles with OSM fallback, disk cache, generated offline fallback |

## 3. Runtime flow

### 3.1 Startup

1. `main.dart` creates `AppState` through `ChangeNotifierProvider`.
2. `RootGate` calls `AppState.initialize()`.
3. Settings load from `shared_preferences`; a device name is generated if absent.
4. SQLite opens (`resqmesh.db`, schema 1).
5. `MeshCryptoService` loads/creates an Ed25519 seed in Android secure storage and loads the
   mesh group passphrase.
6. `MeshService` initializes `NearbyTransport`; availability is checked with Google Play
   services. The native plugin does not start without runtime Nearby permissions.
7. Cached location and data load; verification is recomputed; risk zones and priority
   assessments are derived; connectivity is checked.
8. If permissions/onboarding are complete and demo mode is off, the mesh auto-starts.
9. Root shows Splash → Onboarding → Permissions → `AppShell`.

### 3.2 SOS creation

```
SOS form (category, severity, people, description, GPS/manual fix)
  → AppState.createIncident
  → IncidentRepository.upsert (always, even with no peers)
  → MeshCryptoService.seal (AES-GCM payload, Ed25519 signature)
  → MessageRepository.upsert (status queued)
  → MeshService priority outbox
  → NearbyTransport.send(endpoint, wireBytes) per connected peer
  → transport-level success → status transmitted
  → authenticated remote ack → status acknowledged + receipt count
```

If no peer is connected, the encrypted message remains queued. When a peer connects, the
store-and-forward queue sends recent unexpired messages to that endpoint, subject to dedupe.

### 3.3 Incoming frame pipeline

```
bytes ≤ 96 KiB
  → UTF-8/JSON parse (bounded, typed)
  → demo-over-real-transport guard
  → expiry check
  → Ed25519 verify + origin-ID/public-key binding
  → TOFU check (pin first use, reject changed key)
  → per-origin/global sliding-window rate limit
  → SQLite duplicate check by message ID
  → AES-GCM decrypt
  → type-specific validation
  → persist message/incident, send acknowledgement, notify UI
  → if hop budget remains and origin ≠ self: priority enqueue to other connected peers
```

Rejections are written to the black box (`invalid_dropped`, `duplicate_dropped`,
`rate_limited`, `message_expired`, `security_warning`) without crashing on malformed input.

## 4. Native boundary

Both native implementations expose the same MethodChannel/EventChannel contract
(`com.resqmesh/nearby`, `com.resqmesh/nearby/events`) to one Dart `NearbyTransport`.

**Android — `NearbyMeshPlugin.kt`**

- `status` — Google Play services availability;
- `start` — runtime permission guard, advertising + discovery (`P2P_CLUSTER`), auto-request
  outbound connections when enabled;
- `connect` — user-initiated request;
- `send` — `Payload.fromBytes` to one endpoint, resolving only after the GMS task succeeds;
- `stop` — stop advertising/discovery, disconnect all;
- EventChannel: peer found/lost, connected/disconnected, received bytes, status/errors.

**iOS — `MultipeerMeshPlugin` in `AppDelegate.swift`**

- `status` — MultipeerConnectivity availability;
- `start` — `MCNearbyServiceAdvertiser` + `MCNearbyServiceBrowser` with service type
  `resqmesh-mesh`; auto-invite discovered peers when enabled;
- `connect` — invite a discovered `MCPeerID`;
- `send` — `MCSession.send(..., with: .reliable)` to one peer;
- `stop` — stop advertiser/browser and disconnect the session;
- EventChannel: same peer/payload/status event schema as Android.

The native layers explicitly contain **no** dedupe, trust, TTL, routing, identity or
persistence. That keeps the native surface small and lets the relay protocol be tested without
radios. Incoming connection requests are accepted so a user-initiated connection works; the
`autoConnect` setting governs automatic outbound requests on discovery.

**Platform interoperability:** Android Nearby Connections and iOS MultipeerConnectivity are
different protocols and do not discover each other. Mesh devices must be all Android or all
iOS. The common ResQMesh envelope preserves identical security/relay semantics within each
platform family.

## 5. Persistence

Schema version 1 tables:

| Table | Purpose |
|---|---|
| `incidents` | SOS/hazard records, location provenance, verification, relay/receipt counts, demo flag |
| `messages` | Signed envelope JSON, decrypted payload, hop count, status, transport |
| `peers` | Endpoint identity, display name, connected state, last seen |
| `known_devices` | TOFU-pinned origin public keys and trust state |
| `verifications` | Responder/crowd votes with independent reporter IDs |
| `shelters` | Capacity, occupancy, status, source, demo flag |
| `transmissions` | Per-message/per-endpoint send attempts for store-and-forward evidence |
| `events` | Append-only black-box audit log |
| `location_history` | Last-known and historical fixes with source and timestamp |

All queries use parameters. The database lives in app-private storage on Android and iOS;
backups are disabled on Android. It is **not** SQLCipher-encrypted in this build.

## 6. Security model

- **Identity:** Ed25519 seed per device, stored via `flutter_secure_storage` (Android Keystore / iOS Keychain).
  Device ID = `dev_` + first 8 bytes of SHA-256(public key). Envelopes whose
  `originId` does not match the key are rejected.
- **Integrity/authenticity:** origin signature covers immutable metadata + nonce + ciphertext.
- **Confidentiality:** AES-256-GCM with a key derived by PBKDF2-HMAC-SHA256 (60,000
  iterations) from a shared mesh passphrase. Nonce is 12 bytes; MAC is appended to ciphertext
  before base64 encoding.
- **Trust:** TOFU pinning rejects a changed key for a known origin and logs a warning.
- **Abuse controls:** 96 KiB frame cap, JSON type/length validation, 20/min per origin,
  80/min global, hop cap 12, 12-hour expiry, duplicate ID suppression.
- **Demo guard:** a demo envelope is dropped if the active transport is not simulated.
- **Honest gaps:** shared symmetric group key means members can read/forge as new identities;
  routing metadata isn't signed; TOFU has no revocation UI; database is not encrypted at rest;
  responder PIN is local; no foreground service; no backend sync.

See `SECURITY_AND_LIMITATIONS.md`.

## 7. Intelligence

### 7.1 Hazard clustering

Hazard reports are grouped by category and single-link proximity (≤1,100 m, ≤6 h). The
cluster centroid and radius are computed from reports. Only distinct origin IDs count as
independent. Forwarded copies are the same message ID and are suppressed before this layer.

### 7.2 Transparent risk factors

| Factor | Weight contribution |
|---|---|
| Independent report concentration | up to 28 |
| Maximum observed severity × category multiplier | up to ~34.5 |
| Verification signal | +16 verified / −8 disputed |
| Recency | up to 14 |
| Increasing recent trend | 8 |
| Geographic spread | 2–4 |

Score is capped 0–100 with thresholds severe ≥75, high ≥55, moderate ≥35. Every factor has a
human-readable contribution. Zones are explicitly labelled **estimated**, while report counts
are **observed**.

### 7.3 Rescue priority

| Factor | Max points | Notes |
|---|---|---|
| Danger severity | 40 | Critical 40, high 31, moderate 20, low 10 |
| People affected | 25 | Banded 5–25 |
| Waiting time | 15 | Saturates after 8 h |
| Report reliability | 10 | Responder 10, community 7, unverified 2, disputed 0 |
| Location confidence | 5 | Accuracy × source factor |
| Responder proximity | 5 | 0 if no team position; `factorCoverage` reveals missing input |

Bands: critical ≥75, urgent ≥55, elevated ≥35, routine below. The UI explicitly says no
responder position was available rather than inventing one.

### 7.4 Verification

- radius 450 m, window 90 min, same category;
- independent origins only; an origin cannot verify itself;
- community corroborated at 2 independent reporters;
- any authenticated local responder verification overrides;
- two independent disputes or a responder dispute mark disputed;
- expiry at TTL or 12 h;
- votes and reports are never treated as forwarded-copy confirmations.

## 8. Evacuation routing

`EvacuationService` builds a bounded lat/lng grid (max 72 cells per axis, expanded ~1.4 km
around origin and shelter), marks blocked cells around high-severity/building/road hazards,
adds cost penalties near lower-severity hazards, and runs A* with diagonal movement and
corner-cut prevention. It tries up to four ranked shelters. Warnings always include incomplete
data, unverified/disputed hazards, stale shelter records, non-live origin, and a non-safety
guarantee. This is an advisory geometric route, not a road-network router.

## 9. Demo isolation

- `Settings.demoMode` disables radios and persists as a distinct mode.
- `DemoDataService` deletes only `is_demo = 1` rows, then seeds scenario records with
  `is_demo = 1` / `synthetic = true`.
- Every UI surface shows **DEMO** on synthetic rows and a global banner.
- `MeshService.publishIncident` throws if a demo incident is offered to a non-simulated
  transport.
- Incoming demo envelopes over a real transport are rejected.
- Exiting demo deletes synthetic rows and returns to field mode; real rows are untouched.
- Protocol lab uses `InMemorySecretStore` identities and no transport at all.

## 10. Extension points and gaps

- Add an agency credential/KMS-backed responder identity instead of the local PIN.
- Add SQLCipher and passphrase-derived database protection.
- Add Android foreground and iOS background mesh services for screen-off relay.
- Persist routing/trust evidence with per-hop signatures.
- Add shelter import (GeoJSON/CSV), offline routing over a real road graph, and map region
  prefetch controls.
- Add optional FastAPI sync endpoint and responder dashboard when internet returns; the
  mobile app must remain fully functional without it.
- Add real-hardware instrumentation tests for Android Nearby Connections and iOS MultipeerConnectivity, plus battery/thermal testing.
