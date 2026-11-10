import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/networking/mesh_payloads.dart';
import 'package:resqmesh/core/security/mesh_crypto_service.dart';
import 'package:resqmesh/core/security/secret_store.dart';
import 'package:resqmesh/models/enums.dart';
import 'package:resqmesh/models/mesh_envelope.dart';

void main() {
  const passphrase = 'unit-test-mesh-passphrase-42';
  late MeshCryptoService alice;
  late MeshCryptoService bob;
  late MeshCryptoService eve;

  setUpAll(() async {
    alice = MeshCryptoService(
      secretStore: InMemorySecretStore(),
      deviceName: 'Alice',
      groupPassphrase: passphrase,
    );
    bob = MeshCryptoService(
      secretStore: InMemorySecretStore(),
      deviceName: 'Bob',
      groupPassphrase: passphrase,
    );
    eve = MeshCryptoService(
      secretStore: InMemorySecretStore(),
      deviceName: 'Eve',
      groupPassphrase: 'different-mesh-passphrase-99',
    );
    await alice.initialize();
    await bob.initialize();
    await eve.initialize();
  });

  IncidentReportPayload payload() => IncidentReportPayload(
        category: EmergencyCategory.flood,
        severity: Severity.critical,
        peopleAffected: 4,
        latitude: 20.47,
        longitude: 85.86,
        accuracyMeters: 12,
        locationSource: LocationSource.gps,
        locationTimestamp: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
        description: 'Test SOS payload',
      );

  test('identity IDs are bound to public keys', () {
    expect(MeshCryptoService.isValidDeviceId(alice.identity.deviceId), isTrue);
    expect(alice.identity.deviceId, startsWith('dev_'));
    expect(alice.identity.deviceId, isNot(bob.identity.deviceId));
  });

  test('seal, verify and open round-trips an encrypted incident', () async {
    final envelope = await alice.seal(
      type: MeshMessageType.sos,
      payload: payload().toJson(),
      priority: 9,
    );
    await bob.verifyEnvelope(envelope);
    final opened = await bob.open(envelope);
    expect(opened.payload['category'], 'flood');
    expect(opened.payload['people'], 4);
    expect(opened.envelope.id, envelope.id);
    expect(envelope.originId, alice.identity.deviceId);
  });

  test('a one-bit ciphertext change fails signature verification', () async {
    final envelope = await alice.seal(
      type: MeshMessageType.sos,
      payload: payload().toJson(),
      priority: 9,
    );
    final json = envelope.toJson();
    final cipher = base64Decode(envelope.ciphertext);
    cipher[0] = cipher[0] ^ 0x01;
    json['ciphertext'] = base64Encode(cipher);
    final tampered = MeshEnvelope.fromJson(json);
    await expectLater(
      bob.verifyEnvelope(tampered),
      throwsA(isA<MeshSecurityException>().having(
        (error) => error.code,
        'code',
        'invalid_signature',
      )),
    );
  });

  test('identity mismatch is rejected before signature trust', () async {
    final envelope = await alice.seal(
      type: MeshMessageType.hazard,
      payload: payload().toJson(),
      priority: 6,
    );
    final json = envelope.toJson();
    json['originId'] = bob.identity.deviceId;
    final forged = MeshEnvelope.fromJson(json);
    await expectLater(
      bob.verifyEnvelope(forged),
      throwsA(isA<MeshSecurityException>().having(
        (error) => error.code,
        'code',
        'identity_mismatch',
      )),
    );
  });

  test('wrong group key cannot decrypt even with a valid signature', () async {
    final envelope = await alice.seal(
      type: MeshMessageType.sos,
      payload: payload().toJson(),
      priority: 9,
    );
    await expectLater(
      eve.open(envelope),
      throwsA(isA<MeshSecurityException>()),
    );
  });

  test('expired envelopes are rejected', () async {
    final envelope = await alice.seal(
      type: MeshMessageType.sos,
      payload: payload().toJson(),
      priority: 9,
      ttl: const Duration(hours: 1),
      now: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    );
    await expectLater(
      bob.verifyEnvelope(envelope),
      throwsA(isA<MeshSecurityException>().having(
        (error) => error.code,
        'code',
        'expired',
      )),
    );
  });

  test('relay forwarding keeps the origin signature valid and increments hop',
      () async {
    final envelope = await alice.seal(
      type: MeshMessageType.sos,
      payload: payload().toJson(),
      priority: 9,
    );
    final forwarded = envelope.forwarded(
      relayId: bob.identity.deviceId,
      relayName: bob.identity.displayName,
    );
    expect(forwarded.hopCount, 1);
    expect(forwarded.path, [alice.identity.deviceId]);
    expect(forwarded.signature, envelope.signature);
    await eve.verifyEnvelope(forwarded); // signature is independent of key
    final opened = await bob.open(forwarded);
    expect(opened.payload['description'], 'Test SOS payload');
  });

  test('malformed and oversized envelopes are rejected safely', () {
    expect(
      () => MeshEnvelope.fromWireString('not json'),
      throwsA(isA<FormatException>()),
    );
    final huge = jsonEncode({
      'v': 1,
      'id': 'x' * 100000,
    });
    expect(
      () => MeshEnvelope.fromWireString(huge),
      throwsA(isA<FormatException>()),
    );
  });

  test('wire bytes round-trip', () async {
    final envelope = await alice.seal(
      type: MeshMessageType.sos,
      payload: payload().toJson(),
      priority: 9,
    );
    final Uint8List bytes = envelope.wireBytes;
    final parsed = MeshEnvelope.fromWireString(utf8.decode(bytes));
    expect(parsed.id, envelope.id);
    expect(parsed.toWireString(), envelope.toWireString());
  });
}
