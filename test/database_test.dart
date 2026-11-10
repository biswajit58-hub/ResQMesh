import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/core/database/app_database.dart';
import 'package:resqmesh/core/database/audit_repository.dart';
import 'package:resqmesh/core/database/incident_repository.dart';
import 'package:resqmesh/core/database/message_repository.dart';
import 'package:resqmesh/core/database/shelter_repository.dart';
import 'package:resqmesh/core/database/verification_repository.dart';
import 'package:resqmesh/models/audit_event.dart';
import 'package:resqmesh/models/enums.dart';
import 'package:resqmesh/models/geo_fix.dart';
import 'package:resqmesh/models/incident.dart';
import 'package:resqmesh/models/message_record.dart';
import 'package:resqmesh/models/shelter.dart';
import 'package:resqmesh/models/verification_vote.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory directory;
  late AppDatabase database;
  late IncidentRepository incidents;
  late MessageRepository messages;
  late ShelterRepository shelters;
  late VerificationRepository verifications;
  late AuditRepository audit;

  final now = DateTime.now().toUtc();

  Incident incident({String id = 'incident-1', bool demo = false}) => Incident(
        id: id,
        meshMessageId: id,
        kind: IncidentKind.sos,
        category: EmergencyCategory.flood,
        severity: Severity.critical,
        peopleAffected: 5,
        description: 'Test incident',
        location: GeoFix(
          latitude: 20.47,
          longitude: 85.86,
          accuracyMeters: 10,
          source: LocationSource.gps,
          capturedAt: now,
        ),
        status: IncidentStatus.active,
        verification: VerificationState.unverified,
        createdAt: now,
        updatedAt: now,
        expiresAt: now.add(const Duration(hours: 12)),
        originId: 'dev_origin_1',
        originName: 'Origin',
        isDemo: demo,
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resqmesh_db_test');
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'test.db'),
    );
    incidents = IncidentRepository(database);
    messages = MessageRepository(database);
    shelters = ShelterRepository(database);
    verifications = VerificationRepository(database);
    audit = AuditRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('schema opens and incident CRUD persists JSON fields', () async {
    await incidents.upsert(incident());
    final loaded = await incidents.byId('incident-1');
    expect(loaded, isNotNull);
    expect(loaded!.severity, Severity.critical);
    expect(loaded.peopleAffected, 5);
    expect(loaded.location.source, LocationSource.gps);

    await incidents.updateStatus(
      'incident-1',
      IncidentStatus.responding.wire,
      now.millisecondsSinceEpoch,
    );
    await incidents.updateVerification(
      'incident-1',
      VerificationState.communityCorroborated.wire,
      3,
      now.millisecondsSinceEpoch,
    );
    await incidents.incrementRelay('incident-1');
    await incidents.incrementReceipt('incident-1');
    final updated = await incidents.byId('incident-1');
    expect(updated!.status, IncidentStatus.responding);
    expect(updated.verification, VerificationState.communityCorroborated);
    expect(updated.relayCount, 1);
    expect(updated.receiptCount, 1);
  });

  test('real and demo rows are isolated and demo clear preserves real', () async {
    await incidents.upsert(incident(id: 'real-1'));
    await incidents.upsert(incident(id: 'demo-1', demo: true));
    expect((await incidents.list(demoOnly: true)).length, 1);
    expect(
      (await incidents.list(demoOnly: false, includeDemo: false)).length,
      1,
    );
    await database.clearDemoData();
    expect(await incidents.byId('demo-1'), isNull);
    expect(await incidents.byId('real-1'), isNotNull);
  });

  test('message duplicate lookup and status update', () async {
    final record = MessageRecord(
      id: 'message-1',
      type: MeshMessageType.sos,
      originId: 'dev_origin_1',
      originName: 'Origin',
      senderId: 'dev_origin_1',
      senderName: 'Origin',
      priority: 9,
      hopCount: 0,
      maxHops: 6,
      createdAt: now,
      receivedAt: now,
      expiresAt: now.add(const Duration(hours: 12)),
      status: MeshDeliveryStatus.queued,
      transport: TransportKind.nearby,
      isDemo: false,
      envelopeJson: '{"id":"message-1"}',
      payloadJson: '{"category":"flood"}',
      sizeBytes: 900,
    );
    await messages.upsert(record);
    expect(await messages.exists('message-1'), isTrue);
    expect(await messages.exists('nope'), isFalse);
    await messages.updateStatus(
      'message-1',
      MeshDeliveryStatus.acknowledged,
    );
    expect(
      (await messages.byId('message-1'))!.status,
      MeshDeliveryStatus.acknowledged,
    );
  });

  test('shelter and verification records persist', () async {
    await shelters.upsert(Shelter(
      id: 'shelter-1',
      name: 'Shelter',
      latitude: 20.4,
      longitude: 85.8,
      status: ShelterStatus.open,
      capacity: 100,
      occupancy: 40,
      updatedAt: now,
    ));
    expect((await shelters.list()).single.available, 60);

    await verifications.insert(VerificationVote(
      id: 'vote-1',
      incidentId: 'incident-1',
      reporterId: 'dev_responder',
      reporterName: 'Responder',
      state: VerificationState.responderVerified,
      createdAt: now,
      isResponder: true,
    ));
    final votes = await verifications.forIncident('incident-1');
    expect(votes.single.isResponder, isTrue);
  });

  test('audit events are append-only readable', () async {
    await audit.insert(AuditEvent(
      id: 'event-1',
      type: AuditEventType.sosCreated,
      detail: 'SOS created',
      createdAt: now,
    ));
    final events = await audit.list();
    expect(events.single.type, AuditEventType.sosCreated);
  });
}
