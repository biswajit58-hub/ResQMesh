# Hackathon Presentation & Demo Script

## 1. Elevator pitch

> “When a cyclone takes out the towers, ResQMesh keeps the rescue network alive. Phones talk
> directly to phones over Bluetooth and Wi-Fi, relay each other’s SOS messages, and build a
> transparent local hazard map — no internet, no server, no app store backend.”

## 2. Slide outline (6–7 minutes)

| # | Slide | Key point |
|---|---|---|
| 1 | Title | ResQMesh — an offline peer-to-peer disaster rescue and hazard intelligence network |
| 2 | The failure | Disasters destroy exactly the infrastructure we rely on: towers, power, internet, central platforms |
| 3 | The idea | Every phone becomes a node and a relay; the mesh is the network |
| 4 | Live proof | A→B→C SOS relay with internet and mobile data off (or honest fallback: automated test + Protocol Lab) |
| 5 | What travels | Signed, encrypted envelopes; TTL, hop cap, priority, duplicate suppression, store-and-forward, receipts |
| 6 | Collective intelligence | Hazard clusters, independent-report verification, explainable risk and rescue priority |
| 7 | Evacuation + digital twin | Offline map, shelter finder, A* advisory route with uncertainty, animated situation map |
| 8 | Trust & safety | Ed25519, AES-GCM, TOFU, rate limiting, app-private DB, explicit limits |
| 9 | Impact + next | Field validation, agency credentials, SQLCipher, foreground service, shelter data partnerships |

## 3. Live demo script

### Setup before judges arrive

- Three phones: A (resident), B (relay), C (volunteer), same app build, same mesh key, all on the same platform family (all Android or all iPhone).
- Mobile data and Wi-Fi internet disabled on all; Bluetooth/Wi-Fi radios on.
- App foreground, battery optimization off, permissions granted.
- Devices named `ResQ-A`, `ResQ-B`, `ResQ-C`; mesh started; peer counts visible.
- Backup: Demo Lab with Flood scenario loaded on one phone; Protocol Lab ready.
- Screenshots of working screens in `docs/screenshots/` in case hardware fails.

### 0:00–0:45 — Hook

“This phone has no internet, no mobile data, and no server connection. In the next two minutes
I’ll send an SOS from it through another phone to a rescue volunteer’s phone — and get a
receipt back.”

### 0:45–2:30 — Three-device relay

1. Show all three phones with **mobile data OFF** and **Wi-Fi internet OFF**; show Bluetooth/
   Wi-Fi radios on.
2. Show the mesh screen on each: peers discovered/connected.
3. On A: tap **SOS**, use GPS/manual location, select **Flood**, **Critical**, 6 people,
   description “Family trapped on rooftop, water rising”.
4. Confirm and send. Show the status progression.
5. On B: open **Alerts**; the incident appeared. Open **Disaster black box**; point to
   `message_received` and `message_forwarded`. Emphasise: B is a relay, not a server.
6. On C: open **Message inbox**; the SOS is there at hop 1. Point to the incident.
7. On A: open the incident; show **Receipt confirmed** and receipt count. Open the black box to
   show the acknowledgement hops.
8. Say clearly: “This is best-effort. A receipt is not a rescue guarantee.”

### 2:30–3:30 — Explain the protocol in one breath

- The native transport (Nearby Connections on Android, MultipeerConnectivity on iOS) is only a
  byte pipe.
- ResQMesh adds unique IDs, Ed25519 signatures, AES-256-GCM encryption, TTL, hop limits,
  duplicate suppression, priority outbox and store-and-forward.
- A relay cannot forge the origin signature. It can forward without reading the plaintext in a
  pairwise E2E design; in this group-key build, members can decrypt by design.

### 3:30–5:00 — Intelligence and verification

1. Open **Disaster intelligence**. Show a hazard cluster:
   - observed count vs estimated risk;
   - expansion factors with contributions;
   - “estimated, not a sensor measurement”.
2. Open **Rescue priority**. Show severity/people/waiting/reliability/location factors and the
   missing responder-proximity message (“0/5, not guessed”).
3. Open an incident. Show **verification**: unverified → community corroborated only from
   distinct origin devices; forwarded copies don’t count; responder verification/dispute.
4. Open **Digital twin**. Drag the time window; show markers/risk circles; state that peer
   positions are not invented.

### 5:00–6:00 — Evacuation, black box, trust

1. Shelter finder → route. Show the red advisory warnings: incomplete data, no safety
   guarantee, hazard buffers.
2. Black box export JSON; point out audit coverage.
3. Security slide: Ed25519, AES-GCM, TOFU, rate limits, app-private DB. Then state the limits
   out loud: shared group key, local responder PIN, no SQLCipher, no foreground service.

### 6:00–6:30 — Close

“ResQMesh turns the phones already in people’s pockets into a resilient, explainable local
rescue network. The next step is field validation with real responders, agency credentials and
authoritative shelter data.”

## 4. Backup demo if radios fail

Do **not** pretend the simulation is a radio test. Say: “The physical radio test is blocked in
this room; here is the automated three-node relay proof and the in-memory Protocol Lab.”

1. Open **Protocol Lab** in the app. Run it.
2. Show the steps: A seals SOS, B forwards with hop count 1, C receives and acknowledges,
   duplicate replay rejected, tampered ciphertext rejected, expired envelope rejected.
3. Show `test/relay_integration_test.dart` output:
   `flutter test test/relay_integration_test.dart`.
4. Show the Field Test guide and explain exactly how to reproduce on three phones.

This is credible because it is clearly labelled and does not claim real radio success.

## 5. Judge Q&A

**Q: Is this actually peer-to-peer or just a mock?**
A: Android uses real Nearby Connections in Kotlin; iOS uses MultipeerConnectivity in Swift. Dart implements the multi-hop protocol once for both. The three-node integration test uses a fake transport because the build environment has no three physical phones; the in-app Protocol Lab is explicitly a simulation. Android and iOS do not interoperate. We do not claim a hardware relay we did not perform, and the iOS source was not compiled here because this host is Windows.

**Q: What if no one is nearby?**
A: The SOS is still stored locally and queued. When a peer reconnects before TTL, store-and-
forward sends it. There is no guarantee that a peer ever appears.

**Q: How do you stop fake reports?**
A: Forwarded copies don’t count. Community corroboration requires distinct origin devices
within 450 m / 90 min. A local responder can verify/dispute, but that PIN is a local role gate,
not an agency identity.

**Q: What is the AI?**
A: Transparent rule-based local analytics, not an ML model. We prioritise explainability and
offline determinism. Every risk/priority score lists its factors. No environmental prediction
is claimed.

**Q: What about privacy?**
A: Payloads are AES-GCM encrypted with a group key, identities are Ed25519, DB is app-private,
backups are disabled. Limitations: shared group key, no SQLCipher, data is visible to group
members by design.

**Q: Does it replace 112/911?**
A: No. It is a complement when networks are down. It does not contact emergency services and
provides no delivery or rescue guarantee.

**Q: What would you do with more time?**
A: Real three-phone validation, SQLCipher, foreground service, pairwise E2E, per-hop
signatures, shelter/road data partnerships, agency credentials, and an optional FastAPI sync
dashboard.

## 6. Demo checklist

- [ ] Three phones charged, same app build/version, same mesh key, same platform family
- [ ] Mobile data + Wi-Fi internet off; BT/Wi-Fi on
- [ ] Permissions granted; app foreground; battery optimization off
- [ ] Mesh started; peers visible
- [ ] Demo Lab flood scenario preloaded as backup
- [ ] Protocol Lab rehearsed
- [ ] Screenshots in `docs/screenshots/`
- [ ] Field-test guide open on laptop
- [ ] Honest wording: “best-effort”, “no guarantee”, “local responder gate”
