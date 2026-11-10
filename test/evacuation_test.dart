import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/models/enums.dart';
import 'package:resqmesh/models/geo_fix.dart';
import 'package:resqmesh/models/incident.dart';
import 'package:resqmesh/models/shelter.dart';
import 'package:resqmesh/services/evacuation_service.dart';

void main() {
  const service = EvacuationService();
  final now = DateTime.now().toUtc();

  GeoFix fix(double lat, double lng) => GeoFix(
        latitude: lat,
        longitude: lng,
        accuracyMeters: 10,
        source: LocationSource.gps,
        capturedAt: now,
      );

  Shelter shelter({
    String id = 's1',
    double lat = 20.4800,
    double lng = 85.8600,
    ShelterStatus status = ShelterStatus.open,
    int capacity = 100,
    int occupancy = 30,
    bool demo = false,
  }) =>
      Shelter(
        id: id,
        name: 'Test shelter',
        latitude: lat,
        longitude: lng,
        status: status,
        capacity: capacity,
        occupancy: occupancy,
        updatedAt: now,
        isDemo: demo,
      );

  Incident hazard({
    double lat = 20.4740,
    double lng = 85.8600,
    EmergencyCategory category = EmergencyCategory.flood,
    Severity severity = Severity.critical,
  }) =>
      Incident(
        id: 'hazard',
        kind: IncidentKind.hazard,
        category: category,
        severity: severity,
        peopleAffected: 0,
        description: 'blocking hazard',
        location: fix(lat, lng),
        status: IncidentStatus.active,
        verification: VerificationState.unverified,
        createdAt: now,
        updatedAt: now,
        expiresAt: now.add(const Duration(hours: 6)),
        originId: 'dev_hazard',
        originName: 'hazard',
      );

  test('computes an advisory route around a blocking flood point', () {
    final result = service.computeRoute(
      origin: fix(20.4700, 85.8600),
      shelters: [shelter(demo: true)],
      hazards: [hazard()],
      now: now,
    );
    expect(result.isSuccess, isTrue);
    final route = result.route!;
    expect(route.waypoints.length, greaterThan(2));
    expect(route.distanceMeters, greaterThan(0));
    expect(route.estimatedMinutes, greaterThan(0));
    expect(route.isGuaranteedSafe, isFalse);
    expect(route.hazardsConsidered, 1);
    expect(route.warnings, isNotEmpty);
    expect(route.warnings.join(' ').toLowerCase(), contains('advisory'));
    expect(route.warnings.join(' ').toLowerCase(), contains('synthetic'));
  });

  test('renders a warning when no hazard reports exist', () {
    final result = service.computeRoute(
      origin: fix(20.4700, 85.8600),
      shelters: [shelter()],
      hazards: const [],
      now: now,
    );
    expect(result.isSuccess, isTrue);
    expect(
      result.route!.warnings.join(' ').toLowerCase(),
      contains('no local hazard points'),
    );
  });

  test('fails cleanly when no shelter is cached', () {
    final result = service.computeRoute(
      origin: fix(20.4700, 85.8600),
      shelters: const [],
      hazards: const [],
      now: now,
    );
    expect(result.isSuccess, isFalse);
    expect(result.error, isNotNull);
  });

  test('ranks open shelters with capacity before full shelters', () {
    final options = service.rankShelters(
      origin: fix(20.4700, 85.8600),
      shelters: [
        shelter(id: 'far', lat: 20.5000, occupancy: 90),
        shelter(id: 'full', lat: 20.4710, status: ShelterStatus.full),
        shelter(id: 'near-open', lat: 20.4720),
      ],
    );
    expect(options.first.shelter.id, 'near-open');
    final fullIndex = options.indexWhere((e) => e.shelter.id == 'full');
    final farIndex = options.indexWhere((e) => e.shelter.id == 'far');
    expect(fullIndex, greaterThan(farIndex));
  });

  test('disputed hazards still carry warnings', () {
    final disputed = Incident(
      id: 'h2',
      kind: IncidentKind.hazard,
      category: EmergencyCategory.blockedRoad,
      severity: Severity.high,
      peopleAffected: 0,
      description: 'disputed block',
      location: fix(20.4750, 85.8604),
      status: IncidentStatus.active,
      verification: VerificationState.disputed,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(hours: 6)),
      originId: 'dev_h2',
      originName: 'h2',
    );
    final result = service.computeRoute(
      origin: fix(20.4700, 85.8600),
      shelters: [shelter()],
      hazards: [disputed],
      now: now,
    );
    expect(result.isSuccess, isTrue);
    expect(result.route!.warnings.join(' ').toLowerCase(), contains('disputed'));
  });
}
