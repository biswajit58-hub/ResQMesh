# Three-Device Field Test — A → B → C Relay

This is the most important proof of concept. It uses **real radios**: Android Nearby
Connections or iOS MultipeerConnectivity, not the in-app simulation. All three phones must be
on the same platform family; the two transports do not discover each other.

## 1. What this test proves (and does not prove)

**Proves:** with mobile data and Wi-Fi internet disabled, an SOS created on phone A is
received by phone B, forwarded by B, received by phone C, and an authenticated receipt finds
its way back to A through B. The black box on B records `message_forwarded`; C's inbox shows
the incident; A's message status becomes `acknowledged`.

**Does not prove:** guaranteed delivery, rescue response, safety, continued relay with the
screen off, or Android↔iOS interoperability. The native transports are best-effort and this
build has no foreground service.

## 2. Hardware and topology

- 3 phones of the same platform family: all Android 7.0+ with Google Play services, or all
  iPhone on iOS 15+. Bluetooth + Wi-Fi enabled.
- Same app build and same mesh network key on all three.
- Recommended physical separation: put **B between A and C**, with A and C far enough apart
  that they cannot discover each other directly. Otherwise A–C may connect directly and the
  test would not prove multi-hop.

```text
[A stranded]  ── within peer range ──▶ [B relay] ── within peer range ──▶ [C volunteer]
      ▲                                                                             │
      └──────────────────── ack: C → B → A (best-effort) ◀──────────────────────────┘
```

Names used below: **A = stranded resident**, **B = relay**, **C = rescue volunteer**.

## 3. Prepare the phones

1. Install the same app build on all three:
   - **Android:** `adb install -r dist/resqmesh-release.apk` or copy the APK and install it.
   - **iOS:** build/install the same Xcode/TestFlight build; see [`IOS_BUILD.md`](IOS_BUILD.md).
2. Open ResQMesh, complete onboarding, and grant:
   - **Android:** precise location, Nearby devices / Bluetooth scan, connect, advertise,
     Nearby Wi-Fi devices (Android 13+).
   - **iOS:** precise location, Bluetooth if prompted, and **Local Network** when the mesh starts.
3. **Disable mobile data and Wi-Fi internet** on all three phones. Keep Bluetooth and Wi-Fi
   hardware **on**. Do not enable airplane mode in a way that turns off Bluetooth/Wi-Fi.
4. Settings → **Mesh network key** on each phone: set the **same** passphrase (≥12 chars).
   The default demo key is public; change it.
5. Keep ResQMesh in the foreground and disable battery optimization.
6. Set device names: `ResQ-A`, `ResQ-B`, `ResQ-C` (Settings → Device name).
7. On each phone, More → Nearby Mesh Devices → **Start mesh**. Wait for peer counts to settle.

## 4. Run the relay

### Device A — stranded resident

1. Tap the big red **SOS**.
2. Location: acquire GPS or enter coordinates. Last-known location is acceptable but is
   displayed with its timestamp and is **not** a live fix.
3. Choose category (e.g., Flood), severity (Critical), people (e.g., 6), and a short
   description.
4. Tap **SEND SOS** and confirm.
5. Observe status: `Stored locally` / `Queued` → `Sent to peer` → eventually
   `Receipt confirmed`.
6. Do **not** expect “delivered to rescue”. Only a receipt count is meaningful.

### Device B — relay

1. The incident should appear in **Alerts** and **Disaster black box**.
2. Open the black box and find:
   - `message_received` for A's ID
   - `message_sent` to A's endpoint (ack)
   - `message_forwarded` to C's endpoint
3. Leave B in the foreground.

### Device C — rescue volunteer

1. Open **Message inbox**; the forwarded SOS should appear. Open its incident detail.
2. C automatically sends an authenticated receipt acknowledgement back toward A.
3. Optionally sign in as responder (More → Responder, set a local PIN) and mark the incident
   **Responder verify** or **Responding**.

### Device A — confirm the receipt

1. Open the incident detail. The message status should become **Receipt confirmed** and the
   receipt counter should increase.
2. Open the black box and verify `message_acknowledged` references the original message ID.
3. Relaunch A, B and C while nearby: the stored message should be re-sent to reconnected peers
   (store-and-forward) until TTL expiry.

## 5. Expected evidence checklist

| Evidence | Device | Pass condition |
|---|---|---|
| SOS created locally | A | Incident in Alerts; black box `sos_created` |
| Incident reaches relay | B | Incident visible; `message_received` |
| Relay forwarding | B | `message_forwarded`, hop count increases |
| Incident reaches volunteer | C | Inbox shows SOS; incident detail opens |
| Authenticated receipt | A | Status `Receipt confirmed`; `message_acknowledged` |
| Duplicate protection | any | Replayed frame logs `duplicate_dropped`, no extra incident |
| No internet | all | Mobile data/Wi-Fi internet off; transfer still occurs |
| Demo separation | any | Demo records show DEMO and never appear on real radios |

Take screenshots of A's SOS, B's black-box forwarded event, C's inbox and A's receipt.

## 6. Troubleshooting

| Problem | Action |
|---|---|
| No peers | Keep screens on; toggle mesh off/on on all devices; check permissions; move closer; verify Google Play services. |
| Only A–B connect | Move B closer to C; ensure A–C are out of range; restart discovery. |
| A never gets receipt | Wait; acks are best-effort. Check B's black box. C may be a dead end if B disconnected. |
| Message stuck queued | No peer connected at send time. Keep A open near B; store-and-forward should send on reconnect. |
| “Nearby radio unavailable” | Android: Play services missing/disabled or emulator. iOS: confirm the app is built for device, not a simulator. Use physical phones. |
| iOS peers do not appear | Allow **Local Network** in Settings → Privacy & Security → Local Network → ResQMesh; restart the mesh on all iPhones. |
| Android and iPhone do not see each other | Expected. Nearby Connections and MultipeerConnectivity do not interoperate; use one platform family per mesh. |
| “Cannot decrypt” | Network keys differ. Set the same passphrase on all devices and resend. |
| Identity key changed warning | A known origin presented a different key. Verify the device out of band; do not ignore. |
| App killed by Android | Keep foreground; disable battery optimization. No foreground service in this build. |

## 8. iOS three-iPhone variant

The same A→B→C protocol works over iOS MultipeerConnectivity, but it is an **iOS-only mesh**:

1. Build the same app on three iPhones from Xcode with the same bundle ID and signing team.
2. Set the same mesh network key on each.
3. Start the mesh and accept the **Local Network** prompt on all three.
4. Disable mobile data and Wi-Fi internet; keep Bluetooth and Wi-Fi radios on.
5. Put B between A and C. A sends SOS; B relays; C acknowledges.
6. A should show **Receipt confirmed**, B should log `message_forwarded`, and C should show the
   incident in the inbox.

No iOS IPA is included in this repository because the build host is Windows. See
[`IOS_BUILD.md`](IOS_BUILD.md) for Xcode setup, signing, Local Network troubleshooting and the
list of what remains unverified. Do not present the Swift transport as hardware-tested until
this procedure has run on three iPhones.
## 7. Honest reporting

If a three-phone radio test cannot be performed, say so. The repository includes:

- a **three-node automated integration test** using the real relay state machine over a fake
  byte transport (`test/relay_integration_test.dart`);
- an in-app **Protocol Lab** with three in-memory identities, no radios;
- this field-test guide.

Neither automated test is a substitute for the physical radio test. Do not present the
simulation as a live three-device transmission.
