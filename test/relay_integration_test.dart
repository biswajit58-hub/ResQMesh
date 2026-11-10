import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/core/database/app_database.dart';
import 'package:resqmesh/core/database/audit_repository.dart';
import 'package:resqmesh/core/database/incident_repository.dart';
import 'package:resqmesh/core/database/known_device_repository.dart';
import 'package:resqmesh/core/database/message_repository.dart';
import 'package:resqmesh/core/database/peer_repository.dart';
import 'package:resqmesh/core/database/transmission_repository.dart';
import 'package:resqmesh/core/security/mesh_crypto_service.dart';
import 'package:resqmesh/core/security/secret_store.dart';
import 'package:resqmesh/core/security/trust_service.dart';
import 'package:resqmesh/models/enums.dart';
import 'package:resqmesh/models/geo_fix.dart';
import 'package:resqmesh/models/incident.dart';
import 'package:resqmesh/models/mesh_envelope.dart';
import 'package:resqmesh/services/audit_service.dart';
import 'package:resqmesh/services/mesh_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/fake_transport.dart';

class _Node {
  _Node({
    required this.name,
    required this.database,
    required this.repo,
    required this.messages,
    required this.audit,
    required this.crypto,
    required this.mesh,
    required this.transport,
  });

  final String name;
  final AppDatabase database;
  final IncidentRepository repo;
  final MessageRepository messages;
  final AuditService audit;
  final MeshCryptoService crypto;
  final MeshService mesh;
  final FakeTransport transport;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory directory;
  late FakeTransportHub hub;
  late _Node a;
  late _Node b;
  late _Node c;

  Future<_Node> createNode(
    String name,
    String passphrase,
  ) async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, '$name.db'),
    );
    final transport = FakeTransport(
      hub: hub,
      nodeId: 'endpoint-$name',
      deviceName: name,
    );
    final crypto = MeshCryptoService(
      secretStore: InMemorySecretStore(),
      deviceName: name,
      groupPassphrase: passphrase,
    );
    await crypto.initialize();
    final auditService = AuditService(AuditRepository(db));
    final mesh = MeshService(
      crypto: crypto,
      trust: TrustService(KnownDeviceRepository(db)),
      peers: PeerRepository(db),
      messages: MessageRepository(db),
      incidents: IncidentRepository(db),
      transmissions: TransmissionRepository(db),
      audit: auditService,
      transport: transport,
      onChanged: () {},
    );
    await mesh.initialize();
    return _Node(
      name: name,
      database: db,
      repo: IncidentRepository(db),
      messages: MessageRepository(db),
      audit: auditService,
      crypto: crypto,
      mesh: mesh,
      transport: transport,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resqmesh_mesh_test');
    hub = FakeTransportHub();
    const passphrase = 'relay-integration-passphrase-1';
    a = await createNode('A', passphrase);
    b = await createNode('B', passphrase);
    c = await createNode('C', passphrase);
    hub.link(a.transport.nodeId, b.transport.nodeId);
    hub.link(b.transport.nodeId, c.transport.nodeId);
  });

  tearDown(() async {
    // Presence, acknowledgements and store-and-forward run asynchronously.
    // Let them settle before shutting transports and closing SQLite. The test
    // suite runs under Dart test's event loop; two seconds avoids teardown races
    // on slower CI machines.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await a.mesh.shutdown();
    await b.mesh.shutdown();
    await c.mesh.shutdown();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await a.database.close();
    await b.database.close();
    await c.database.close();
    hub.nodes.clear();
    hub.links.clear();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('three-node relay: A → B → C, C ack → B → A, duplicate rejected',
      () async {
    await a.mesh.start(deviceName: 'A');
    await b.mesh.start(deviceName: 'B');
    await c.mesh.start(deviceName: 'C');
    hub.announceLinks();

    await waitUntil(
      () async => a.mesh.connectedPeers.isNotEmpty && b.mesh.connectedPeers.length >= 2,
      reason: 'Nodes did not connect over the fake transport',
    );

    final now = DateTime.now().toUtc();
    final incident = Incident(
      id: 'sos-relay-0001',
      meshMessageId: 'sos-relay-0001',
      kind: IncidentKind.sos,
      category: EmergencyCategory.flood,
      severity: Severity.critical,
      peopleAffected: 6,
      description: 'Family trapped on roof',
      location: GeoFix(
        latitude: 20.4718,
        longitude: 85.8642,
        accuracyMeters: 12,
        source: LocationSource.gps,
        capturedAt: now,
      ),
      status: IncidentStatus.active,
      verification: VerificationState.unverified,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(hours: 12)),
      originId: a.crypto.identity.deviceId,
      originName: 'A',
    );
    await a.repo.upsert(incident);
    await a.mesh.publishIncident(incident);

    await waitUntil(
      () async => await c.repo.byId(incident.id) != null,
      reason: 'C never received the relayed SOS',
    );
    final atC = await c.repo.byId(incident.id);
    expect(atC, isNotNull);
    expect(atC!.description, 'Family trapped on roof');

    final atB = await b.messages.byId(incident.id);
    expect(atB, isNotNull);
    expect(atB!.hopCount, 0);
    final atCMessage = await c.messages.byId(incident.id);
    expect(atCMessage!.hopCount, 1);
    expect(atCMessage.envelopeJson, isNotEmpty);

    await waitUntil(
      () async {
        final message = await a.messages.byId(incident.id);
        return message?.status == MeshDeliveryStatus.acknowledged;
      },
      reason: 'A never received the relayed acknowledgement',
    );
    final sourceMessage = await a.messages.byId(incident.id);
    expect(sourceMessage!.status, MeshDeliveryStatus.acknowledged);
    final withReceipts = await a.repo.byId(incident.id);
    expect(withReceipts!.receiptCount, greaterThanOrEqualTo(1));

    final bAudit = await b.audit.list();
    expect(
      bAudit.any((event) => event.type == AuditEventType.messageForwarded),
      isTrue,
    );
    final cAudit = await c.audit.list();
    expect(
      cAudit.any((event) => event.type == AuditEventType.messageAcknowledged),
      isFalse,
    );

    // Replay the exact forwarded frame into C from B. The already-seen message
    // ID must be dropped before processing, not counted again.
    final before = c.mesh.duplicateCount;
    c.transport.emitPayload(
      b.transport.nodeId,
      'B',
      utf8.encode(atCMessage.envelopeJson),
    );
    await waitUntil(
      () async => c.mesh.duplicateCount > before,
      reason: 'Duplicate was not detected',
    );
    expect(await c.repo.byId(incident.id), isNotNull);

    final cAuditAfter = await c.audit.list();
    expect(
      cAuditAfter.any((event) => event.type == AuditEventType.duplicateDropped),
      isTrue,
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('forged origin identity is rejected and not stored', () async {
    await a.mesh.start(deviceName: 'A');
    await b.mesh.start(deviceName: 'B');
    hub.announceLinks();
    await waitUntil(() async => b.mesh.connectedPeers.isNotEmpty);

    final now = DateTime.now().toUtc();
    final envelope = await a.crypto.seal(
      type: MeshMessageType.sos,
      payload: {
        'category': 'flood',
        'severity': 'critical',
        'people': 2,
        'lat': 20.47,
        'lng': 85.86,
        'accuracy': 10,
        'locationSource': 'gps',
        'locationTs': now.millisecondsSinceEpoch,
        'createdAt': now.millisecondsSinceEpoch,
      },
      priority: 9,
      messageId: 'forged-0001',
    );
    final json = envelope.toJson();
    json['originId'] = b.crypto.identity.deviceId;
    final forged = MeshEnvelope.fromJson(json);
    b.transport.emitPayload(
      a.transport.nodeId,
      'A',
      utf8.encode(forged.toWireString()),
    );
    await waitUntil(
      () async => b.mesh.invalidCount > 0,
      reason: 'Forged identity was not rejected',
    );
    expect(await b.repo.byId('forged-0001'), isNull);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
