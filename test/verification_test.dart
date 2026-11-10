import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/models/enums.dart';
import 'package:resqmesh/models/geo_fix.dart';
import 'package:resqmesh/models/incident.dart';
import 'package:resqmesh/models/verification_vote.dart';
import 'package:resqmesh/services/verification_service.dart';

void main() {
  const service = VerificationService();
  final now = DateTime.now().toUtc();

  Incident incident({
    required String id,
    required String origin,
    double lat = 20.4700,
    double lng = 85.8600,
    EmergencyCategory category = EmergencyCategory.flood,
    DateTime? createdAt,
    VerificationState state = VerificationState.unverified,
    Duration ttl = const Duration(hours: 12),
    bool demo = false,
  }) {
    final created = createdAt ?? now.subtract(const Duration(minutes: 10));
    return Incident(
      id: id,
      meshMessageId: id,
      kind: IncidentKind.hazard,
      category: category,
      severity: Severity.high,
      peopleAffected: 0,
      description: 'test',
      location: GeoFix(
        latitude: lat,
        longitude: lng,
        accuracyMeters: 15,
        source: LocationSource.gps,
        capturedAt: created,
      ),
      status: IncidentStatus.active,
      verification: state,
      createdAt: created,
      updatedAt: created,
      expiresAt: created.add(ttl),
      originId: origin,
      originName: origin,
      isDemo: demo,
    );
  }

  test('a single report is unverified', () {
    final subject = incident(id: 'a', origin: 'dev_origin_a');
    final result = service.evaluate(
      incident: subject,
      allIncidents: [subject],
      votes: const [],
      now: now,
    );
    expect(result.state, VerificationState.unverified);
    expect(result.independentReporters, 1);
  });

  test('a forwarded copy from the same origin is not independent', () {
    final subject = incident(id: 'a', origin: 'dev_origin_a');
    final forwardedCopy = incident(id: 'copy', origin: 'dev_origin_a');
    final result = service.evaluate(
      incident: subject,
      allIncidents: [subject, forwardedCopy],
      votes: const [],
      now: now,
    );
    expect(result.independentReporters, 1);
    expect(result.state, VerificationState.unverified);
  });

  test('two distinct origins within radius and window corroborate', () {
    final subject = incident(id: 'a', origin: 'dev_origin_a');
    final independent = incident(
      id: 'b',
      origin: 'dev_origin_b',
      lat: 20.4702,
      lng: 85.8602,
    );
    final result = service.evaluate(
      incident: subject,
      allIncidents: [subject, independent],
      votes: const [],
      now: now,
    );
    expect(result.independentReporters, 2);
    expect(result.state, VerificationState.communityCorroborated);
    expect(result.corroboratingIncidentIds, contains('b'));
  });

  test('a report beyond the radius does not corroborate', () {
    final subject = incident(id: 'a', origin: 'dev_origin_a');
    final far = incident(
      id: 'b',
      origin: 'dev_origin_b',
      lat: 20.4800,
      lng: 85.8600,
    );
    final result = service.evaluate(
      incident: subject,
      allIncidents: [subject, far],
      votes: const [],
      now: now,
    );
    expect(result.independentReporters, 1);
  });

  test('two independent responder disputes mark disputed', () {
    final subject = incident(id: 'a', origin: 'dev_origin_a');
    final votes = [
      VerificationVote(
        id: 'v1',
        incidentId: 'a',
        reporterId: 'dev_x',
        reporterName: 'X',
        state: VerificationState.disputed,
        createdAt: now,
        isResponder: true,
      ),
      VerificationVote(
        id: 'v2',
        incidentId: 'a',
        reporterId: 'dev_y',
        reporterName: 'Y',
        state: VerificationState.disputed,
        createdAt: now,
      ),
    ];
    final result = service.evaluate(
      incident: subject,
      allIncidents: [subject],
      votes: votes,
      now: now,
    );
    expect(result.state, VerificationState.disputed);
    expect(result.disputeVotes, 2);
  });

  test('a responder verification overrides community corroboration', () {
    final subject = incident(id: 'a', origin: 'dev_origin_a');
    final vote = VerificationVote(
      id: 'v1',
      incidentId: 'a',
      reporterId: 'dev_responder',
      reporterName: 'Responder',
      state: VerificationState.responderVerified,
      createdAt: now,
      isResponder: true,
    );
    final result = service.evaluate(
      incident: subject,
      allIncidents: [subject],
      votes: [vote],
      now: now,
    );
    expect(result.state, VerificationState.responderVerified);
  });

  test('an origin cannot verify its own report via a vote', () {
    final subject = incident(id: 'a', origin: 'dev_origin_a');
    final ownVote = VerificationVote(
      id: 'v1',
      incidentId: 'a',
      reporterId: 'dev_origin_a',
      reporterName: 'self',
      state: VerificationState.responderVerified,
      createdAt: now,
      isResponder: true,
    );
    final result = service.evaluate(
      incident: subject,
      allIncidents: [subject],
      votes: [ownVote],
      now: now,
    );
    expect(result.state, VerificationState.unverified);
  });

  test('demo and real reports never corroborate each other', () {
    final real = incident(id: 'a', origin: 'dev_origin_a');
    final demo = incident(id: 'b', origin: 'dev_origin_b', demo: true);
    final result = service.evaluate(
      incident: real,
      allIncidents: [real, demo],
      votes: const [],
      now: now,
    );
    expect(result.independentReporters, 1);
  });

  test('a disputed nearby report does not corroborate', () {
    final subject = incident(id: 'a', origin: 'dev_origin_a');
    final disputed = incident(
      id: 'b',
      origin: 'dev_origin_b',
      lat: 20.4701,
      lng: 85.8601,
      state: VerificationState.disputed,
    );
    final result = service.evaluate(
      incident: subject,
      allIncidents: [subject, disputed],
      votes: const [],
      now: now,
    );
    expect(result.independentReporters, 1);
    expect(result.state, VerificationState.unverified);
  });

  test('expired reports become expired', () {
    final expired = incident(
      id: 'a',
      origin: 'dev_origin_a',
      createdAt: now.subtract(const Duration(hours: 14)),
    );
    final result = service.evaluate(
      incident: expired,
      allIncidents: [expired],
      votes: const [],
      now: now,
    );
    expect(result.state, VerificationState.expired);
  });
}
