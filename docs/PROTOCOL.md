# ResQMesh Wire Protocol v1

## 1. Scope

This document specifies the signed, encrypted application envelope carried over the native
peer transport: Android Nearby Connections or iOS MultipeerConnectivity. The transport provides
only a byte pipe between endpoint IDs; ResQMesh defines the message semantics below.

The two native transports do not interoperate with each other. The envelope and relay rules are
identical, but a mesh must be all Android or all iOS.

## 1.1 Transport mapping

| Platform | Native transport | Service identifier | Endpoint ID |
|---|---|---|---|
| Android | Google Nearby Connections (`P2P_CLUSTER`) | `com.resqmesh.p2p.v1` | GMS endpoint ID |
| iOS | MultipeerConnectivity (`MCNearbyServiceAdvertiser`/`Browser`) | `resqmesh-mesh` | `ios-<uuid>` mapped from `MCPeerID` |

Both transport adapters expose the same Dart `NearbyTransport` interface and EventChannel
events. Relaying, crypto and persistence never depend on which platform delivered the bytes.

## 2. Envelope JSON

```json
{
  "v": 1,
  "id": "d3b9d5b2-...",
  "type": "sos",
  "originId": "dev_1a2b3c4d5e6f7788",
  "originName": "ResQ-A1B2",
  "originPublicKey": "<base64 Ed25519 public key, 32 bytes>",
  "createdAt": 1790000000000,
  "expiresAt": 1790043200000,
  "maxHops": 6,
  "priority": 9,
  "demo": false,
  "nonce": "<base64 12-byte AES-GCM nonce>",
  "ciphertext": "<base64 ciphertext || 16-byte GCM tag>",
  "signature": "<base64 Ed25519 signature, 64 bytes>",
  "hopCount": 0,
  "path": [],
  "senderId": "dev_1a2b3c4d5e6f7788",
  "senderName": "ResQ-A1B2"
}
```

Types: `sos`, `hazard`, `ack`, `shelter_update`, `status_update`, `presence`, `text`.

## 3. Canonical signature

The origin signs the UTF-8 bytes of the following fields joined by U+001F:

```
RQM1
id
type.wire
originId
originName
originPublicKey
createdAt
expiresAt
maxHops
priority
demo ? 1 : 0
nonce
ciphertext
```

`hopCount`, `path`, `senderId` and `senderName` are deliberately excluded: relays must change
them. That means relays can alter routing metadata (for example to drop a message early).
Expiry, hop bounds and path length are enforced independently at each receiver, and the
ciphertext/immutable metadata cannot be changed. A production v2 should add a per-hop
signature chain.

## 4. Identity binding

```
deviceId = "dev_" + hex(SHA-256(publicKey)[0..8])
```

`originId` must equal this derivation. This prevents a sender from claiming another device's
ID without its key. TOFU pinning additionally detects key replacement for a known origin.

## 5. Encryption

- Algorithm: AES-256-GCM.
- Key: PBKDF2-HMAC-SHA256(passphrase, salt=`"resqmesh-group-v1"`, iterations=60,000, 256 bits).
  The derived key is cached in memory.
- Nonce: 12 random bytes (`newNonce`).
- Wire `ciphertext` = base64(ciphertext || MAC).
- GCM authentication failure produces `undecryptable`; the frame is not stored as a valid
  incident and is audited.

This is **group encryption**, not pairwise end-to-end encryption. Any member knowing the group
passphrase can decrypt and could forge traffic under a newly generated identity. The default
passphrase is a public demo value and must be changed for field use.

## 6. Payloads

### 6.1 Incident (`sos`, `hazard`)

```json
{
  "category": "flood",
  "severity": "critical",
  "people": 7,
  "lat": 20.4718,
  "lng": 85.8642,
  "accuracy": 12.0,
  "locationSource": "gps",
  "locationTs": 1790000000000,
  "createdAt": 1790000000000,
  "description": "Family on rooftop…",
  "locationDescription": "Near Bidanasi Chhak"
}
```

Validation: coordinates finite and in range; people 0–100,000; descriptions bounded; payload
≤48 KiB before encryption.

### 6.2 Receipt acknowledgement (`ack`)

```json
{
  "ackFor": "<original message id>",
  "target": "<original origin device id>",
  "receiverId": "dev_…",
  "receiverName": "ResQ-C",
  "receivedAt": 1790000000000
}
```

Acknowledgements are routed to `target`; each relay forwards them if the hop budget remains.
When the target receives one, it marks `acknowledged` and increments the receipt count. An
acknowledgement means “a device processed this envelope”, **not** “rescue is coming”.

### 6.3 Presence

```json
{
  "deviceId": "dev_…",
  "name": "ResQ-A",
  "protocol": 1,
  "capabilities": ["sos", "hazard", "ack", "relay"]
}
```

Presence is direct, max 1 hop, 10-minute TTL; it maps an ephemeral Nearby endpoint to a
persistent device identity. It is not persisted in the inbox.

## 7. Relay state machine

On receipt:

1. frame ≤96 KiB and valid UTF-8 JSON;
2. known type and bounded fields;
3. reject `demo` if transport is real;
4. reject `now > expiresAt`;
5. verify Ed25519 signature and identity binding;
6. TOFU pin check;
7. rate limit;
8. reject if message ID already in local store;
9. decrypt/validate payload;
10. persist; for incidents, send an acknowledgement to the sender and notify the UI;
11. if `hopCount < maxHops`, origin ≠ self and self not already in `path`, construct a
    forwarded envelope (`hopCount + 1`, path + origin, sender = self) and enqueue it for all
    connected peers except the one that delivered it.

## 8. Priorities

Priority derives from severity, with a bump for ≥10 people affected:

| Severity | Base |
|---|---|
| critical | 9 |
| high | 8 |
| moderate | 6 |
| low | 4 |

The outbox is sorted descending by priority, then by creation time, so critical SOS frames go
before newer low-priority chatter.

## 9. Limits

| Limit | Value |
|---|---|
| Envelope wire size | 96 KiB |
| Ciphertext field | 72,000 base64 chars |
| Payload plaintext | 48 KiB |
| Max hops | 12 (SOS/hazard default 6) |
| Default TTL | 12 h (ack 6 h, presence 10 min) |
| Path length | 12 |
| Rate limit | 20/min per origin, 80/min global |
| Presence | 1 hop |

## 10. Failure semantics

There is no transport-level delivery guarantee. A message can be:

- `queued` — stored locally, no successful transport send yet;
- `transmitted` — native transport accepted at least one frame for a connected endpoint;
- `acknowledged` — an authenticated remote receipt arrived;
- `failed` — native send rejected;
- `expired` — TTL passed.

The UI must use these exact meanings. Store-and-forward retries on reconnection and after app
restart, but only within TTL.

## 11. Test vectors / evidence

`test/mesh_crypto_test.dart`, `test/relay_integration_test.dart`, and
`test/protocol_and_localization_test.dart` exercise seal/open, tampering, expiry, identity
binding, three-node relay, acknowledgements and duplicate replay on the VM. The in-app Protocol
Lab runs the same protocol with in-memory identities and **no radios**. Native transport
behaviour (Android or iOS) still requires physical-device testing.
