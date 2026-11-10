import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/models/enums.dart';
import 'package:resqmesh/models/geo_fix.dart';
import 'package:resqmesh/models/incident.dart';
import 'package:resqmesh/models/rescue_team.dart';
import 'package:resqmesh/services/intelligence_service.dart';
import 'package:resqmesh/services/priority_service.dart';

void main() {
  final now = DateTime.now().toUtc();

  Incident incident({
    required String id,
    required String origin,
    required EmergencyCategory category,
    required Severity severity,
    required double lat,
    required double lng,
    int people = 1,
    VerificationState verification = VerificationState.unverified,
    Duration age = const Duration(minutes: 15),
    int receiptCount = 0,
    int relayCount = 0,
    bool demo = false,
  }) {
    final created = now.subtract(age);
    return Incident(
      id: id,
      meshMessageId: id,
      kind: IncidentKind.hazard,
      category: category,
      severity: severity,
      peopleAffected: people,
      description: 'test report',
      location: GeoFix(
        latitude: lat,
        longitude: lng,
        accuracyMeters: 12,
        source: LocationSource.gps,
        capturedAt: created,
      ),
      status: IncidentStatus.active,
      verification: verification,
      createdAt: created,
      updatedAt: created,
      expiresAt: created.add(const Duration(hours: 12)),
      originId: origin,
      originName: origin,
      receiptCount: receiptCount,
      relayCount: relayCount,
      isDemo: demo,
    );
  }

  group('hazard intelligence', () {
    test('clusters same-category reports and explains every factor', () {
      final reports = [
        incident(
          id: 'a',
          origin: 'dev_a',
          category: EmergencyCategory.flood,
          severity: Severity.critical,
          lat: 20.4700,
          lng: 85.8600,
        ),
        incident(
          id: 'b',
          origin: 'dev_b',
          category: EmergencyCategory.flood,
          severity: Severity.high,
          lat: 20.4705,
          lng: 85.8605,
        ),
        incident(
          id: 'c',
          origin: 'dev_c',
          category: EmergencyCategory.flood,
          severity: Severity.high,
          lat: 20.4710,
          lng: 85.8610,
        ),
      ];
      const service = IntelligenceService();
      final zones = service.analyze(reports, now: now);
      expect(zones, hasLength(1));
      expect(zones.first.observedCount, 3);
      expect(zones.first.independentReporters, 3);
      expect(zones.first.factors, isNotEmpty);
      expect(
        zones.first.factors.map((e) => e.code),
        containsAll([
          'independent_reports',
          'severity',
          'verification',
          'recency',
          'trend',
          'spread',
        ]),
      );
      final explained = zones.first.factors.fold<double>(
        0,
        (sum, factor) => sum + factor.contribution,
      );
      expect(zones.first.score, closeTo(explained.clamp(0, 100), 0.01));
      expect(zones.first.isEstimated, isTrue);
    });

    test('same-origin reports are not counted as independent', () {
      final reports = [
        incident(
          id: 'a',
          origin: 'dev_same',
          category: EmergencyCategory.fire,
          severity: Severity.high,
          lat: 20.30,
          lng: 85.80,
        ),
        incident(
          id: 'b',
          origin: 'dev_same',
          category: EmergencyCategory.fire,
          severity: Severity.high,
          lat: 20.3001,
          lng: 85.8001,
        ),
      ];
      const service = IntelligenceService();
      final zones = service.analyze(reports, now: now);
      expect(zones.first.observedCount, 2);
      expect(zones.first.independentReporters, 1);
    });
  });

  group('rescue priority', () {
    test('critical, many people, older and verified ranks higher', () {
      const service = PriorityService();
      final critical = incident(
        id: 'critical',
        origin: 'dev_a',
        category: EmergencyCategory.collapsedBuilding,
        severity: Severity.critical,
        lat: 20.35,
        lng: 85.82,
        people: 12,
        verification: VerificationState.responderVerified,
        age: const Duration(hours: 3),
      );
      final low = incident(
        id: 'low',
        origin: 'dev_b',
        category: EmergencyCategory.blockedRoad,
        severity: Severity.low,
        lat: 20.36,
        lng: 85.83,
        people: 1,
      );
      final ranked = service.rank(
        incidents: [low, critical],
        rescueTeams: const [],
        now: now,
      );
      expect(ranked.first.incidentId, 'critical');
      expect(ranked.first.score, greaterThan(ranked.last.score));
      expect(ranked.first.factors.map((e) => e.code), contains('proximity'));
      expect(ranked.first.responderDistanceKm, isNull);
      expect(ranked.first.factorCoverage, lessThan(1));
    });

    test('known nearby responder contributes the proximity factor', () {
      const service = PriorityService();
      final target = incident(
        id: 'target',
        origin: 'dev_a',
        category: EmergencyCategory.medical,
        severity: Severity.high,
        lat: 20.30,
        lng: 85.82,
        people: 3,
      );
      final assessment = service.assess(
        incident: target,
        rescueTeams: const [
          RescueTeam(
            id: 'team',
            name: 'Team',
            latitude: 20.301,
            longitude: 85.821,
            unitType: 'medical',
            status: 'available',
            capabilities: ['medical'],
            isDemo: true,
          ),
        ],
        now: now,
      );
      final proximity = assessment.factors
          .firstWhere((factor) => factor.code == 'proximity');
      expect(proximity.points, greaterThan(0));
      expect(assessment.factorCoverage, 1);
      expect(assessment.responderDistanceKm, isNotNull);
    });
  });
}
