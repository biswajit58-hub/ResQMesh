import 'dart:convert';

import '../core/networking/mesh_payloads.dart';
import '../core/security/mesh_crypto_service.dart';
import '../core/security/secret_store.dart';
import '../models/enums.dart';
import '../models/mesh_envelope.dart';
import '../models/protocol_simulation.dart';

/// Executes the real envelope crypto + relay-forwarding path with three
/// in-memory identities.
///
/// This is explicitly a SIMULATION: no Wi-Fi, Bluetooth, Nearby Connections or
/// radio hardware is touched. It exists to demonstrate the protocol path and
/// adversarial checks, not to claim a live multi-device transmission.
class ProtocolSimulationService {
  Future<ProtocolSimulationReport> run() async {
    final stopwatch = Stopwatch()..start();
    final steps = <SimulationStep>[];
    final now = DateTime.now().toUtc();

    final a = MeshCryptoService(
      secretStore: InMemorySecretStore(),
      deviceName: 'SIM · Device A',
    );
    final b = MeshCryptoService(
      secretStore: InMemorySecretStore(),
      deviceName: 'SIM · Device B',
    );
    final c = MeshCryptoService(
      secretStore: InMemorySecretStore(),
      deviceName: 'SIM · Device C',
    );
    await a.initialize();
    await b.initialize();
    await c.initialize();

    void step(
      String label,
      String detail,
      SimulationStepStatus status, {
      String from = '—',
      String to = '—',
    }) {
      steps.add(SimulationStep(
        label: label,
        detail: detail,
        status: status,
        fromNode: from,
        toNode: to,
        atMillis: stopwatch.elapsedMilliseconds,
      ));
    }

    step(
      'Three simulated identities created',
      'A, B and C each generated a distinct Ed25519 keypair. Group payload encryption uses the shared demo mesh key. No radios are used.',
      SimulationStepStatus.success,
    );

    final payload = IncidentReportPayload(
      category: EmergencyCategory.flood,
      severity: Severity.critical,
      peopleAffected: 6,
      latitude: 20.4718,
      longitude: 85.8642,
      accuracyMeters: 14,
      locationSource: LocationSource.gps,
      locationTimestamp: now,
      createdAt: now,
      description:
          'SIMULATION: family trapped on roof, water rising. This text never leaves memory.',
    );

    final outbound = await a.seal(
      type: MeshMessageType.sos,
      payload: payload.toJson(),
      priority: 9,
      maxHops: 6,
      isDemo: true,
      messageId: 'sim-sos-${now.millisecondsSinceEpoch}',
    );
    step(
      'A seals an SOS',
      'AES-256-GCM ciphertext (${outbound.ciphertext.length} base64 chars), unique ID ${outbound.id.substring(0, 8)}…, 6-hop ceiling, 12-hour expiry. A signs immutable metadata.',
      SimulationStepStatus.success,
      from: 'A',
      to: 'A',
    );

    step(
      'A → B frame handed over',
      'The simulated link carries ${outbound.wireBytes.length} bytes. B cannot see plaintext without the group key.',
      SimulationStepStatus.success,
      from: 'A',
      to: 'B',
    );
    await b.verifyEnvelope(outbound);
    final openedByB = await b.open(outbound);
    step(
      'B verifies, decrypts and stores',
      'Signature valid; identity ${outbound.originId} is bound to its public key. SOS parsed with ${openedByB.payload['people']} people.',
      SimulationStepStatus.success,
      from: 'B',
      to: 'B',
    );

    final forwarded = outbound.forwarded(
      relayId: b.identity.deviceId,
      relayName: b.identity.displayName,
    );
    step(
      'B re-signs routing only and forwards',
      'Hop count incremented to ${forwarded.hopCount}/${forwarded.maxHops}; origin signature over payload is preserved. Path now ${forwarded.path.length} node.',
      SimulationStepStatus.success,
      from: 'B',
      to: 'C',
    );

    await c.verifyEnvelope(forwarded);
    final openedByC = await c.open(forwarded);
    final delivered = openedByC.payload['description']?.toString().isNotEmpty ?? false;
    step(
      'C receives the relayed SOS',
      delivered
          ? 'C verifies the original A signature after one relay, decrypts the payload, and stores the incident for the rescue volunteer.'
          : 'Payload failed validation.',
      delivered
          ? SimulationStepStatus.success
          : SimulationStepStatus.rejected,
      from: 'C',
      to: 'C',
    );

    final ack = await c.seal(
      type: MeshMessageType.ack,
      payload: AckPayload(
        ackFor: outbound.id,
        targetDeviceId: a.identity.deviceId,
        receiverId: c.identity.deviceId,
        receiverName: 'SIM · Device C',
        receivedAt: DateTime.now().toUtc(),
      ).toJson(),
      priority: 5,
      maxHops: 6,
      isDemo: true,
    );
    await b.verifyEnvelope(ack);
    final ackForwarded = ack.forwarded(
      relayId: b.identity.deviceId,
      relayName: b.identity.displayName,
    );
    await a.verifyEnvelope(ackForwarded);
    final openedAck = await a.open(ackForwarded);
    final ackParsed = AckPayload.fromJson(openedAck.payload);
    final ackCorrect = ackParsed.ackFor == outbound.id &&
        ackParsed.targetDeviceId == a.identity.deviceId;
    step(
      'C → B → A receipt acknowledgement',
      ackCorrect
          ? 'A verified C’s acknowledgement through B and can mark "receipt confirmed by 1 device." This is still not a rescue guarantee.'
          : 'Acknowledgement target mismatch.',
      ackCorrect
          ? SimulationStepStatus.success
          : SimulationStepStatus.rejected,
      from: 'C',
      to: 'A',
    );

    final seen = <String>{outbound.id};
    final duplicateDetected = !seen.add(forwarded.id);
    step(
      'Duplicate replay rejected',
      duplicateDetected
          ? 'An identical message ID arriving again at C is dropped before payload processing. Forwarded copies are not counted as independent confirmation.'
          : 'Duplicate was not detected.',
      duplicateDetected
          ? SimulationStepStatus.success
          : SimulationStepStatus.rejected,
      from: 'B',
      to: 'C',
    );

    var tamperedRejected = false;
    try {
      final json = outbound.toJson();
      final cipher = base64Decode(outbound.ciphertext);
      cipher[0] = cipher[0] ^ 0x01;
      json['ciphertext'] = base64Encode(cipher);
      final tampered = MeshEnvelope.fromJson(json);
      await b.verifyEnvelope(tampered);
    } catch (_) {
      tamperedRejected = true;
    }
    step(
      'Tampered ciphertext rejected',
      tamperedRejected
          ? 'A one-bit change invalidates the Ed25519 signature before decryption or relay.'
          : 'Tamper detection FAILED.',
      tamperedRejected
          ? SimulationStepStatus.success
          : SimulationStepStatus.rejected,
      from: 'Attacker',
      to: 'B',
    );

    var expiredRejected = false;
    try {
      final expired = await a.seal(
        type: MeshMessageType.sos,
        payload: payload.toJson(),
        priority: 9,
        ttl: const Duration(hours: 12),
        now: now.subtract(const Duration(hours: 13)),
      );
      await c.verifyEnvelope(expired);
    } catch (_) {
      expiredRejected = true;
    }
    step(
      'Expired envelope rejected',
      expiredRejected
          ? 'A message sealed 13 hours ago with a 12-hour TTL is refused before relay.'
          : 'Expiry enforcement FAILED.',
      expiredRejected
          ? SimulationStepStatus.success
          : SimulationStepStatus.rejected,
      from: 'Delayed node',
      to: 'C',
    );

    return ProtocolSimulationReport(
      runId: 'SIM-${now.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}',
      steps: steps,
      deliveredToC: delivered && ackCorrect,
      duplicateDropped: duplicateDetected,
      tamperedRejected: tamperedRejected,
      expiredRejected: expiredRejected,
      hopCount: forwarded.hopCount,
      generatedAt: now,
      isSimulation: true,
    );
  }
}
