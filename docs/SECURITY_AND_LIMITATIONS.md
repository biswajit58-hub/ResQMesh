# Security & Limitations

ResQMesh is a hackathon prototype. This document separates what is implemented and tested
from what is not. No security control is claimed merely because the UI mentions it.

## 1. Implemented controls

### Identity and authenticity

- Each device generates an Ed25519 keypair on first launch. The 32-byte seed is stored in
  `flutter_secure_storage` (Android Keystore-backed encrypted preferences).
- Public key → device ID binding: `dev_` + first 8 bytes of SHA-256(public key). A receiver
  recomputes this and rejects mismatched `originId`.
- The origin signs canonical immutable envelope metadata + nonce + ciphertext. Relays cannot
  alter the payload or its origin signature.

### Confidentiality and integrity

- AES-256-GCM encrypts payloads.
- Key derivation: PBKDF2-HMAC-SHA256, 60,000 iterations, 256 bits, salt `resqmesh-group-v1`.
- Nonce: 12 random bytes per message; GCM tag is appended to ciphertext on the wire.
- Authentication failure, malformed base64, wrong key length and non-JSON payloads are
  rejected without crashing.

### Trust

- Trust-on-first-use (TOFU): the first public key seen for an origin is pinned in SQLite.
- A later different key for the same `originId` is refused and logged as `security_warning`.
- This detects post-first-contact impersonation. It is **not** a PKI, certificate authority,
  agency credential, or revocation system.

### Abuse and reliability

- Frame maximum 96 KiB; payload maximum 48 KiB.
- JSON type/bounds validation for every field, paths and base64 fields.
- Maximum hops 12 (default 6); message TTL 12 h (ack 6 h, presence 10 min).
- Duplicate message IDs are stored uniquely and replayed copies are dropped before payload
  processing.
- Per-origin sliding-window rate limit 20/min; global 80/min.
- Unknown message types and malformed envelopes are dropped and audited.
- Failed native sends are recorded; store-and-forward retries on reconnection.
- Acknowledgements are authenticated but explicitly best-effort.

### Local data

- SQLite lives in app-private storage on Android and iOS; identity secrets use Android Keystore or iOS Keychain via `flutter_secure_storage`.
- `allowBackup=false` and `fullBackupContent=false` in the manifest.
- The black box is append-only through the app’s repository API (no update/delete method for
  real audit events).
- JSON export is explicit and user-initiated.

### Responder actions

- Local 4–12 character PIN, PBKDF2-HMAC-SHA256 with a random per-device salt.
- 20-minute in-memory session; actions require an active session.
- All responder actions are audited with the local device identity.

### Demo separation

- Every demo row carries `is_demo = 1`; the UI labels it DEMO.
- Demo mode stops the real transport.
- `MeshService` refuses to publish a demo incident over a non-simulated transport.
- Incoming demo envelopes on a real transport are rejected.
- Exiting demo deletes only synthetic rows.

## 2. Deliberate limitations / non-goals

| Area | Limitation |
|---|---|
| Group encryption | All devices sharing a passphrase can decrypt each other's mesh payloads. This is group confidentiality, not pairwise E2E. Any member could forge traffic under a new identity. |
| Default key | The default passphrase `ResQMesh-field-demo-2026` is public. It must be changed for field use. |
| Trust | TOFU has no revocation/rotation UX. A pinned device that changes keys stays blocked until the app database is reset (there is no “forget device” button yet). |
| Routing metadata | Hop count, path and sender name are not origin-signed. A malicious relay can drop, delay or reset routing fields. Expiry/dup/TTL still limit impact. |
| Database at rest | SQLite is app-private but **not** SQLCipher-encrypted. A rooted/backup-extracted device may expose stored payloads and identity references. |
| Responder identity | The local PIN is not verified against any agency, hospital or government registry. It should not be described as an official credential. |
| Delivery | No guaranteed delivery. Store-and-forward only retries while the app runs and before TTL. |
| Background | No Android foreground service or iOS background mesh mode. Relay may stop when the app is backgrounded/killed. Keep it in the foreground. |
| iOS permissions | iOS requires **Local Network** permission for MultipeerConnectivity discovery and prompts separately from Bluetooth/location. Denying Local Network prevents peer discovery. |
| Platform interoperability | Android Nearby Connections and iOS MultipeerConnectivity do not discover each other. An all-Android or all-iOS mesh is required; there is no cross-platform bridge. |
| Radios | Native transports are best-effort and platform-dependent. Real three-phone radio testing was not possible in the build environment. The iOS target was not compiled on this Windows host. |
| Mapping | Offline routing is an A* grid over local hazard points, not a road-network or hydrology model. It can route through unobserved hazards. |
| Shelter data | Demo shelters are synthetic. Field use needs an authoritative shelter import/verification pipeline. |
| Intelligence | Rule-based only. No flood prediction, no weather/sensor feed, no trained ML. |
| Network status | The ONLINE indicator is a DNS reachability check, not a guaranteed internet path or backend sync. |
| Backend | No FastAPI/PostgreSQL/Next.js component is included. Online sync is future work. |
| Localization | Core navigation, forms, statuses and safety labels exist in English, Hindi and Odia; long synthetic scenario narratives and some technical diagnostics remain English. |

## 3. Threat model

In scope:

- a malicious or malfunctioning mesh peer sending oversized/malformed/tampered/expired/
  replayed messages;
- rate-limit abuse;
- identity impersonation after first contact (detected by TOFU);
- accidental demo/real data mixing;
- local attacker with physical access to an unlocked device (mitigated only by Android and the
  local PIN for responder actions);
- data leakage through backup (disabled).

Out of scope:

- a compromised Android OS or rooted device;
- a group member who knows the shared passphrase and intentionally reads traffic;
- nation-state traffic analysis;
- denial of service by jamming radios;
- verified government identity;
- secure routing metadata;
- database encryption at rest;
- screen-off long-running relay.

## 4. Data/privacy notes

- SOS/hazard locations are sensitive. They are stored locally and broadcast to the mesh group
  when a user sends them.
- The app does not upload location to a backend.
- CARTO (primary) and OSM (fallback) map tiles are fetched over HTTPS only when internet is
  available; tile requests reveal coarse map areas to the tile provider. Cached tiles work
  offline and a locally generated grid tile is used if both providers are blocked.
- Local export contains incidents, messages, shelters, events and device identity. Treat it as
  sensitive.
- Demo mode contains only synthetic records and makes no radio transmissions.

## 5. What a production deployment would require

1. Agency-issued, hardware-backed responder credentials and signature verification.
2. Pairwise E2E or per-network keys with a real key-exchange/rotation UX.
3. Per-hop signatures and replay-resistant routing.
4. SQLCipher + Keystore-wrapped database key.
5. Foreground service, battery/thermal validation, and OEM background restrictions testing.
6. Real-hardware multi-hop testing at scale and in degraded RF conditions.
7. Authoritative shelter/road/hazard data integration and legal disclaimers.
8. Security audit, penetration test, privacy impact assessment, and local emergency-service
   integration.
