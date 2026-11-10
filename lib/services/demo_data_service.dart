import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/database/audit_repository.dart';
import '../core/database/incident_repository.dart';
import '../core/database/message_repository.dart';
import '../core/database/peer_repository.dart';
import '../core/database/shelter_repository.dart';
import '../core/database/verification_repository.dart';
import '../models/enums.dart';
import '../models/audit_event.dart';
import '../models/geo_fix.dart';
import '../models/incident.dart';
import '../models/message_record.dart';
import '../models/peer_device.dart';
import '../models/rescue_team.dart';
import '../models/shelter.dart';
import '../models/verification_vote.dart';

class DemoContent {
  const DemoContent({
    required this.scenario,
    required this.title,
    required this.summary,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.rescueTeams,
    required this.topologyLabels,
  });

  final DemoScenario scenario;
  final String title;
  final String summary;
  final double centerLatitude;
  final double centerLongitude;
  final List<RescueTeam> rescueTeams;
  final List<String> topologyLabels;
}

/// Generates explicitly synthetic scenario data. Nothing here is produced by a
/// sensor or a real radio, and every row is stored with `is_demo = 1`.
class DemoDataService {
  DemoDataService({
    required AppDatabase db,
    required IncidentRepository incidents,
    required MessageRepository messages,
    required ShelterRepository shelters,
    required PeerRepository peers,
    required VerificationRepository verifications,
    required AuditRepository audit,
  })  : _db = db,
        _incidents = incidents,
        _messages = messages,
        _shelters = shelters,
        _peers = peers,
        _verifications = verifications,
        _audit = audit;

  final AppDatabase _db;
  final IncidentRepository _incidents;
  final MessageRepository _messages;
  final ShelterRepository _shelters;
  final PeerRepository _peers;
  final VerificationRepository _verifications;
  final AuditRepository _audit;
  final _uuid = const Uuid();

  DemoContent contentFor(DemoScenario scenario) => _contentFor(scenario);

  DemoContent contentWithTeams(DemoScenario scenario) =>
      _contentFor(scenario).copyWithTeams(_teamsFor(scenario));

  List<RescueTeam> teamsFor(DemoScenario scenario) => _teamsFor(scenario);

  Future<DemoContent> seed(DemoScenario scenario) async {
    if (scenario == DemoScenario.none) {
      throw ArgumentError('A demo scenario is required');
    }
    await _db.clearDemoData();
    final now = DateTime.now().toUtc();
    final content = _contentFor(scenario);
    final incidents = _incidentsFor(scenario, now);
    for (final incident in incidents) {
      await _incidents.upsert(incident);
      await _messages.upsert(_messageFor(incident));
    }
    for (final shelter in _sheltersFor(scenario, now)) {
      await _shelters.upsert(shelter);
    }
    for (final peer in _peersFor(scenario)) {
      await _peers.upsert(peer);
    }
    final votes = _votesFor(scenario, now);
    for (final vote in votes) {
      await _verifications.insert(vote);
    }
    final ackIncident = incidents.first;
    await _messages.upsert(MessageRecord(
      id: 'demo-ack-${scenario.wire}-001',
      type: MeshMessageType.ack,
      originId: 'demo-device-relay-b',
      originName: 'DEMO · Relay B',
      senderId: 'demo-device-relay-b',
      senderName: 'DEMO · Relay B',
      priority: 5,
      hopCount: 1,
      maxHops: 6,
      createdAt: now.subtract(const Duration(minutes: 16)),
      receivedAt: now.subtract(const Duration(minutes: 15)),
      expiresAt: now.add(const Duration(hours: 11)),
      status: MeshDeliveryStatus.acknowledged,
      transport: TransportKind.simulated,
      isDemo: true,
      envelopeJson: jsonEncode({
        'demo': true,
        'note': 'Synthetic acknowledgement; no radios were used.',
      }),
      payloadJson: jsonEncode({
        'ackFor': ackIncident.id,
        'receiverName': 'DEMO · Relay B',
        'target': 'demo-device-asha',
      }),
      sizeBytes: 640,
    ));
    await _audit.insert(AuditEvent(
      id: _uuid.v4(),
      type: AuditEventType.demoSeeded,
      detail:
          'Synthetic "${scenario.name}" scenario loaded: ${incidents.length} incidents, 1 acknowledgement, 5 shelters, ${_peersFor(scenario).length} scenario nodes. No radios used.',
      createdAt: now,
      isDemo: true,
    ));
    return content.copyWithTeams(_teamsFor(scenario));
  }

  Future<void> clear() async {
    await _db.clearDemoData();
    await _audit.insert(AuditEvent(
      id: _uuid.v4(),
      type: AuditEventType.demoCleared,
      detail: 'All synthetic demo rows were deleted. Real local data was not modified.',
      createdAt: DateTime.now().toUtc(),
      isDemo: false,
    ));
  }

  DemoContent _contentFor(DemoScenario scenario) {
    return switch (scenario) {
      DemoScenario.flood => const DemoContent(
          scenario: DemoScenario.flood,
          title: 'Mahanadi Flood — Cuttack & Bhubaneswar',
          summary:
              'Synthetic flood scenario: rooftop rescues, blocked ring road, medical needs and shelter pressure. All records are training data.',
          centerLatitude: 20.4650,
          centerLongitude: 85.8640,
          rescueTeams: [],
          topologyLabels: [
            'A · Stranded resident',
            'B · Neighbour relay',
            'C · Rescue volunteer',
          ],
        ),
      DemoScenario.earthquake => const DemoContent(
          scenario: DemoScenario.earthquake,
          title: 'Bhubaneswar Building Collapse',
          summary:
              'Synthetic earthquake scenario: collapsed structures, fire, blocked access and mass-casualty triage. All records are training data.',
          centerLatitude: 20.3515,
          centerLongitude: 85.8190,
          rescueTeams: [],
          topologyLabels: [
            'A · Trapped resident',
            'B · Apartment relay',
            'C · NDRF volunteer',
          ],
        ),
      DemoScenario.landslide => const DemoContent(
          scenario: DemoScenario.landslide,
          title: 'Khandagiri Landslide',
          summary:
              'Synthetic landslide scenario: hillside slope failure, severed road access and an isolated community. All records are training data.',
          centerLatitude: 20.2395,
          centerLongitude: 85.7790,
          rescueTeams: [],
          topologyLabels: [
            'A · Isolated villager',
            'B · Hill relay',
            'C · ODRAF volunteer',
          ],
        ),
      DemoScenario.none => const DemoContent(
          scenario: DemoScenario.none,
          title: 'No scenario',
          summary: 'No synthetic data is active.',
          centerLatitude: 20.2961,
          centerLongitude: 85.8245,
          rescueTeams: [],
          topologyLabels: [],
        ),
    };
  }

  List<Incident> _incidentsFor(DemoScenario scenario, DateTime now) {
    switch (scenario) {
      case DemoScenario.flood:
        return [
          _incident(
            id: 'demo-flood-sos-001',
            kind: IncidentKind.sos,
            category: EmergencyCategory.flood,
            severity: Severity.critical,
            people: 7,
            lat: 20.4718,
            lng: 85.8642,
            now: now,
            minutesAgo: 18,
            origin: 'demo-device-asha',
            originName: 'DEMO · Asha (resident)',
            description:
                'Family of seven on a rooftop. Water at first-floor level. One elderly person needs oxygen.',
            verification: VerificationState.communityCorroborated,
          ),
          _incident(
            id: 'demo-flood-sos-002',
            kind: IncidentKind.sos,
            category: EmergencyCategory.medical,
            severity: Severity.high,
            people: 2,
            lat: 20.2980,
            lng: 85.8180,
            now: now,
            minutesAgo: 32,
            origin: 'demo-device-ravi',
            originName: 'DEMO · Ravi (resident)',
            description:
                'Two children with fever and dehydration. The nearest road is under water.',
            verification: VerificationState.unverified,
          ),
          _incident(
            id: 'demo-flood-haz-001',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.flood,
            severity: Severity.high,
            people: 0,
            lat: 20.4702,
            lng: 85.8630,
            now: now,
            minutesAgo: 22,
            origin: 'demo-device-relay-b',
            originName: 'DEMO · Relay B',
            description:
                'Culvert overflowing; waist-deep water across the approach lane.',
          ),
          _incident(
            id: 'demo-flood-haz-002',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.blockedRoad,
            severity: Severity.high,
            people: 0,
            lat: 20.4680,
            lng: 85.8610,
            now: now,
            minutesAgo: 35,
            origin: 'demo-device-priya',
            originName: 'DEMO · Priya (cyclist)',
            description:
                'Mahanadi ring road submerged. Two cars stuck; do not route through this section.',
            verification: VerificationState.disputed,
          ),
          _incident(
            id: 'demo-flood-haz-003',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.infrastructure,
            severity: Severity.moderate,
            people: 0,
            lat: 20.2890,
            lng: 85.8310,
            now: now,
            minutesAgo: 50,
            origin: 'demo-device-om',
            originName: 'DEMO · Om (volunteer)',
            description:
                'Low-hanging power lines beside the shelter access road. Keep clear.',
          ),
          _incident(
            id: 'demo-flood-haz-004',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.flood,
            severity: Severity.moderate,
            people: 0,
            lat: 20.4655,
            lng: 85.8700,
            now: now,
            minutesAgo: 75,
            origin: 'demo-device-sita',
            originName: 'DEMO · Sita (resident)',
            description:
                'Knee-deep water near the bus stand; passable on foot with caution.',
          ),
          _incident(
            id: 'demo-flood-med-001',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.medical,
            severity: Severity.high,
            people: 0,
            lat: 20.2850,
            lng: 85.8080,
            now: now,
            minutesAgo: 15,
            origin: 'demo-device-vol-3',
            originName: 'DEMO · Volunteer 3',
            description:
                'Temporary medical camp has insulin but needs clean water and dry blankets.',
          ),
          _incident(
            id: 'demo-flood-collapse-001',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.collapsedBuilding,
            severity: Severity.critical,
            people: 0,
            lat: 20.4735,
            lng: 85.8680,
            now: now,
            minutesAgo: 12,
            origin: 'demo-device-fire-1',
            originName: 'DEMO · Fire unit observer',
            description:
                'Old single-storey structure partially collapsed after waterlogging. No confirmed occupants.',
          ),
        ];
      case DemoScenario.earthquake:
        return [
          _incident(
            id: 'demo-eq-sos-001',
            kind: IncidentKind.sos,
            category: EmergencyCategory.collapsedBuilding,
            severity: Severity.critical,
            people: 12,
            lat: 20.3520,
            lng: 85.8190,
            now: now,
            minutesAgo: 11,
            origin: 'demo-device-anita',
            originName: 'DEMO · Anita (resident)',
            description:
                'Four-storey building partially collapsed. Voices heard under the south stairwell. Dust is heavy.',
            verification: VerificationState.communityCorroborated,
          ),
          _incident(
            id: 'demo-eq-sos-002',
            kind: IncidentKind.sos,
            category: EmergencyCategory.medical,
            severity: Severity.critical,
            people: 4,
            lat: 20.3350,
            lng: 85.8180,
            now: now,
            minutesAgo: 20,
            origin: 'demo-device-kiran',
            originName: 'DEMO · Kiran (resident)',
            description:
                'Four injured, including one with a suspected spinal injury. Open ground nearby is clear.',
          ),
          _incident(
            id: 'demo-eq-haz-001',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.collapsedBuilding,
            severity: Severity.critical,
            people: 0,
            lat: 20.3515,
            lng: 85.8195,
            now: now,
            minutesAgo: 14,
            origin: 'demo-device-neighbour',
            originName: 'DEMO · Neighbour',
            description: 'Second building leaning; debris blocking the lane.',
          ),
          _incident(
            id: 'demo-eq-haz-002',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.fire,
            severity: Severity.high,
            people: 0,
            lat: 20.3510,
            lng: 85.8200,
            now: now,
            minutesAgo: 9,
            origin: 'demo-device-security',
            originName: 'DEMO · Security guard',
            description:
                'Smoke and small fire near a damaged meter box. Avoid east approach.',
          ),
          _incident(
            id: 'demo-eq-haz-003',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.blockedRoad,
            severity: Severity.high,
            people: 0,
            lat: 20.3400,
            lng: 85.8120,
            now: now,
            minutesAgo: 28,
            origin: 'demo-device-driver',
            originName: 'DEMO · Ambulance driver',
            description:
                'Debris blocks both lanes. Ambulance cannot pass; needs clearing crew.',
          ),
          _incident(
            id: 'demo-eq-haz-004',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.infrastructure,
            severity: Severity.high,
            people: 0,
            lat: 20.3300,
            lng: 85.8300,
            now: now,
            minutesAgo: 40,
            origin: 'demo-device-utility',
            originName: 'DEMO · Utility observer',
            description: 'Fallen transformer and live cable across pavement.',
          ),
          _incident(
            id: 'demo-eq-haz-005',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.medical,
            severity: Severity.moderate,
            people: 0,
            lat: 20.3420,
            lng: 85.8250,
            now: now,
            minutesAgo: 25,
            origin: 'demo-device-clinic',
            originName: 'DEMO · Clinic volunteer',
            description: 'Triage point needs splints, bandages and drinking water.',
          ),
          _incident(
            id: 'demo-eq-haz-006',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.collapsedBuilding,
            severity: Severity.high,
            people: 0,
            lat: 20.3480,
            lng: 85.8260,
            now: now,
            minutesAgo: 48,
            origin: 'demo-device-warden',
            originName: 'DEMO · Building warden',
            description: 'Boundary wall collapsed over parked scooters; lane blocked.',
          ),
        ];
      case DemoScenario.landslide:
        return [
          _incident(
            id: 'demo-ls-sos-001',
            kind: IncidentKind.sos,
            category: EmergencyCategory.landslide,
            severity: Severity.critical,
            people: 5,
            lat: 20.2390,
            lng: 85.7790,
            now: now,
            minutesAgo: 16,
            origin: 'demo-device-maya',
            originName: 'DEMO · Maya (resident)',
            description:
                'Hillside collapsed behind three homes. Two people are unaccounted for; one person has a leg injury.',
            verification: VerificationState.communityCorroborated,
          ),
          _incident(
            id: 'demo-ls-sos-002',
            kind: IncidentKind.sos,
            category: EmergencyCategory.medical,
            severity: Severity.high,
            people: 2,
            lat: 20.2410,
            lng: 85.7810,
            now: now,
            minutesAgo: 24,
            origin: 'demo-device-asha',
            originName: 'DEMO · Asha (health worker)',
            description: 'Two elderly residents need evacuation; one is diabetic.',
          ),
          _incident(
            id: 'demo-ls-haz-001',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.landslide,
            severity: Severity.critical,
            people: 0,
            lat: 20.2385,
            lng: 85.7780,
            now: now,
            minutesAgo: 20,
            origin: 'demo-device-relay-b',
            originName: 'DEMO · Hill relay B',
            description:
                'Fresh crack across the slope; loose boulders still moving. Do not approach the toe of the slide.',
          ),
          _incident(
            id: 'demo-ls-haz-002',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.blockedRoad,
            severity: Severity.high,
            people: 0,
            lat: 20.2360,
            lng: 85.7760,
            now: now,
            minutesAgo: 30,
            origin: 'demo-device-bus',
            originName: 'DEMO · Bus driver',
            description:
                'Main access road buried under mud and rock. No vehicle can pass; footpath uncertain.',
          ),
          _incident(
            id: 'demo-ls-haz-003',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.collapsedBuilding,
            severity: Severity.high,
            people: 0,
            lat: 20.2402,
            lng: 85.7802,
            now: now,
            minutesAgo: 18,
            origin: 'demo-device-neighbour',
            originName: 'DEMO · Neighbour',
            description: 'Kitchen wall collapsed; gas cylinder smell reported.',
          ),
          _incident(
            id: 'demo-ls-haz-004',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.infrastructure,
            severity: Severity.moderate,
            people: 0,
            lat: 20.2440,
            lng: 85.7840,
            now: now,
            minutesAgo: 55,
            origin: 'demo-device-utility',
            originName: 'DEMO · Utility observer',
            description: 'Power pole leaning across the school access path.',
          ),
          _incident(
            id: 'demo-ls-haz-005',
            kind: IncidentKind.hazard,
            category: EmergencyCategory.flood,
            severity: Severity.moderate,
            people: 0,
            lat: 20.2320,
            lng: 85.7720,
            now: now,
            minutesAgo: 68,
            origin: 'demo-device-farmer',
            originName: 'DEMO · Farmer',
            description: 'Drain blocked, standing water at the lower field.',
          ),
        ];
      case DemoScenario.none:
        return const [];
    }
  }

  Incident _incident({
    required String id,
    required IncidentKind kind,
    required EmergencyCategory category,
    required Severity severity,
    required int people,
    required double lat,
    required double lng,
    required DateTime now,
    required int minutesAgo,
    required String origin,
    required String originName,
    required String description,
    VerificationState verification = VerificationState.unverified,
  }) {
    final created = now.subtract(Duration(minutes: minutesAgo));
    return Incident(
      id: id,
      meshMessageId: id,
      kind: kind,
      category: category,
      severity: severity,
      peopleAffected: people,
      description: description,
      location: GeoFix(
        latitude: lat,
        longitude: lng,
        accuracyMeters: 12,
        source: LocationSource.gps,
        capturedAt: created,
        description: 'Synthetic scenario location',
      ),
      status: IncidentStatus.active,
      verification: verification,
      createdAt: created,
      updatedAt: created,
      expiresAt: created.add(const Duration(hours: 12)),
      originId: origin,
      originName: originName,
      independentReporters: verification == VerificationState.communityCorroborated ? 3 : 1,
      isDemo: true,
      synthetic: true,
    );
  }

  MessageRecord _messageFor(Incident incident) => MessageRecord(
        id: incident.id,
        type: incident.kind == IncidentKind.sos
            ? MeshMessageType.sos
            : MeshMessageType.hazard,
        originId: incident.originId,
        originName: incident.originName,
        senderId: incident.originId,
        senderName: incident.originName,
        priority: incident.severity.weight >= 3 ? 8 : 6,
        hopCount: 0,
        maxHops: 6,
        createdAt: incident.createdAt,
        receivedAt: incident.createdAt.add(const Duration(seconds: 20)),
        expiresAt: incident.expiresAt,
        status: MeshDeliveryStatus.acknowledged,
        transport: TransportKind.simulated,
        isDemo: true,
        envelopeJson: jsonEncode({
          'demo': true,
          'note': 'Synthetic record; no radio transmission occurred.',
        }),
        payloadJson: jsonEncode({
          'category': incident.category.wire,
          'severity': incident.severity.wire,
          'people': incident.peopleAffected,
          'description': incident.description,
        }),
        sizeBytes: 1280,
      );

  List<Shelter> _sheltersFor(DemoScenario scenario, DateTime now) {
    final updated = now.subtract(const Duration(minutes: 25));
    switch (scenario) {
      case DemoScenario.flood:
        return [
          Shelter(
            id: 'demo-shelter-flood-1',
            name: 'Cuttack Indoor Stadium Relief Centre',
            latitude: 20.4580,
            longitude: 85.8830,
            status: ShelterStatus.open,
            capacity: 800,
            occupancy: 320,
            updatedAt: updated,
            address: 'Indoor Stadium Road, Cuttack',
            phone: 'DEMO-100',
            notes: 'Synthetic scenario shelter. Boats and medical desk.',
            isDemo: true,
          ),
          Shelter(
            id: 'demo-shelter-flood-2',
            name: 'Bidanasi Government School',
            latitude: 20.4730,
            longitude: 85.8660,
            status: ShelterStatus.open,
            capacity: 300,
            occupancy: 150,
            updatedAt: updated,
            address: 'Bidanasi, Cuttack',
            phone: 'DEMO-101',
            notes: 'Synthetic scenario shelter. Upper-floor hall.',
            isDemo: true,
          ),
          Shelter(
            id: 'demo-shelter-flood-3',
            name: 'Kalinga Stadium Community Hall',
            latitude: 20.2900,
            longitude: 85.8250,
            status: ShelterStatus.open,
            capacity: 1000,
            occupancy: 420,
            updatedAt: updated,
            address: 'Kalinga Stadium, Bhubaneswar',
            phone: 'DEMO-102',
            notes: 'Synthetic scenario shelter. Generator and water tank.',
            isDemo: true,
          ),
          Shelter(
            id: 'demo-shelter-flood-4',
            name: 'Red Cross Bhavan',
            latitude: 20.2860,
            longitude: 85.8420,
            status: ShelterStatus.full,
            capacity: 180,
            occupancy: 180,
            updatedAt: updated,
            address: 'Unit 9, Bhubaneswar',
            phone: 'DEMO-103',
            notes: 'Synthetic scenario shelter. Full.',
            isDemo: true,
          ),
          Shelter(
            id: 'demo-shelter-flood-5',
            name: 'Barabati Indoor Hall',
            latitude: 20.4650,
            longitude: 85.8760,
            status: ShelterStatus.open,
            capacity: 400,
            occupancy: 50,
            updatedAt: updated,
            address: 'Barabati, Cuttack',
            phone: 'DEMO-104',
            notes: 'Synthetic scenario shelter. Accessible entrance.',
            isDemo: true,
          ),
        ];
      case DemoScenario.earthquake:
        return [
          Shelter(
            id: 'demo-shelter-eq-1',
            name: 'KIIT Campus Open Ground',
            latitude: 20.3550,
            longitude: 85.8170,
            status: ShelterStatus.open,
            capacity: 1200,
            occupancy: 430,
            updatedAt: updated,
            address: 'Patia, Bhubaneswar',
            notes: 'Synthetic scenario shelter. Open ground; no structural cover.',
            isDemo: true,
          ),
          Shelter(
            id: 'demo-shelter-eq-2',
            name: 'SAI International Ground',
            latitude: 20.3410,
            longitude: 85.8210,
            status: ShelterStatus.open,
            capacity: 600,
            occupancy: 200,
            updatedAt: updated,
            address: 'Chandrasekharpur, Bhubaneswar',
            notes: 'Synthetic scenario shelter. Triage point.',
            isDemo: true,
          ),
          Shelter(
            id: 'demo-shelter-eq-3',
            name: 'Nayapalli Community Centre',
            latitude: 20.3200,
            longitude: 85.8050,
            status: ShelterStatus.open,
            capacity: 250,
            occupancy: 90,
            updatedAt: updated,
            address: 'Nayapalli, Bhubaneswar',
            notes: 'Synthetic scenario shelter.',
            isDemo: true,
          ),
          Shelter(
            id: 'demo-shelter-eq-4',
            name: 'Rasulgarh Indoor Hall',
            latitude: 20.3100,
            longitude: 85.8400,
            status: ShelterStatus.full,
            capacity: 300,
            occupancy: 300,
            updatedAt: updated,
            address: 'Rasulgarh, Bhubaneswar',
            notes: 'Synthetic scenario shelter. Full.',
            isDemo: true,
          ),
        ];
      case DemoScenario.landslide:
        return [
          Shelter(
            id: 'demo-shelter-ls-1',
            name: 'Khandagiri Community Centre',
            latitude: 20.2500,
            longitude: 85.7880,
            status: ShelterStatus.open,
            capacity: 220,
            occupancy: 70,
            updatedAt: updated,
            address: 'Khandagiri, Bhubaneswar',
            notes: 'Synthetic scenario shelter. Accessible by eastern approach.',
            isDemo: true,
          ),
          Shelter(
            id: 'demo-shelter-ls-2',
            name: 'Ghatikia Government School',
            latitude: 20.2460,
            longitude: 85.7990,
            status: ShelterStatus.open,
            capacity: 350,
            occupancy: 110,
            updatedAt: updated,
            address: 'Ghatikia, Bhubaneswar',
            notes: 'Synthetic scenario shelter. Medical desk.',
            isDemo: true,
          ),
          Shelter(
            id: 'demo-shelter-ls-3',
            name: 'Sundarpada Panchayat Hall',
            latitude: 20.2700,
            longitude: 85.7920,
            status: ShelterStatus.open,
            capacity: 180,
            occupancy: 45,
            updatedAt: updated,
            address: 'Sundarpada, Bhubaneswar',
            notes: 'Synthetic scenario shelter.',
            isDemo: true,
          ),
        ];
      case DemoScenario.none:
        return const [];
    }
  }

  List<PeerDevice> _peersFor(DemoScenario scenario) {
    final now = DateTime.now().toUtc();
    final names = switch (scenario) {
      DemoScenario.flood => [
          'DEMO · A — Stranded resident',
          'DEMO · B — Neighbour relay',
          'DEMO · C — Rescue volunteer',
          'DEMO · ODRAF forward node',
        ],
      DemoScenario.earthquake => [
          'DEMO · A — Trapped resident',
          'DEMO · B — Apartment relay',
          'DEMO · C — NDRF volunteer',
          'DEMO · Triage forward node',
        ],
      DemoScenario.landslide => [
          'DEMO · A — Isolated villager',
          'DEMO · B — Hill relay',
          'DEMO · C — ODRAF volunteer',
          'DEMO · Road-clearance node',
        ],
      DemoScenario.none => <String>[],
    };
    return [
      for (var i = 0; i < names.length; i++)
        PeerDevice(
          endpointId: 'demo-endpoint-${scenario.wire}-$i',
          displayName: names[i],
          deviceId: 'demo-node-$i',
          firstSeen: now.subtract(Duration(minutes: 12 + i * 3)),
          lastSeen: now.subtract(Duration(seconds: i * 7)),
          connected: i < 3,
          transport: TransportKind.simulated,
          isDemo: true,
          lastMessageAt: now.subtract(Duration(minutes: 2 + i)),
        ),
    ];
  }

  List<VerificationVote> _votesFor(DemoScenario scenario, DateTime now) {
    return switch (scenario) {
      DemoScenario.flood => [
          VerificationVote(
            id: 'demo-vote-flood-1',
            incidentId: 'demo-flood-sos-001',
            reporterId: 'demo-responder-odraf-1',
            reporterName: 'DEMO · ODRAF coordinator',
            state: VerificationState.responderVerified,
            createdAt: now.subtract(const Duration(minutes: 10)),
            note: 'Boat crew visual confirmation in synthetic scenario.',
            isResponder: true,
            isDemo: true,
          ),
          VerificationVote(
            id: 'demo-vote-flood-2',
            incidentId: 'demo-flood-haz-002',
            reporterId: 'demo-independent-1',
            reporterName: 'DEMO · Independent observer 1',
            state: VerificationState.disputed,
            createdAt: now.subtract(const Duration(minutes: 14)),
            note: 'Synthetic dispute: water may be lower than reported.',
            isDemo: true,
          ),
          VerificationVote(
            id: 'demo-vote-flood-3',
            incidentId: 'demo-flood-haz-002',
            reporterId: 'demo-independent-2',
            reporterName: 'DEMO · Independent observer 2',
            state: VerificationState.disputed,
            createdAt: now.subtract(const Duration(minutes: 12)),
            note: 'Synthetic dispute: an alternative lane may be open.',
            isDemo: true,
          ),
        ],
      DemoScenario.earthquake => [
          VerificationVote(
            id: 'demo-vote-eq-1',
            incidentId: 'demo-eq-sos-001',
            reporterId: 'demo-responder-ndrf-1',
            reporterName: 'DEMO · NDRF coordinator',
            state: VerificationState.responderVerified,
            createdAt: now.subtract(const Duration(minutes: 6)),
            note: 'Synthetic scenario: search dog indicated live scent.',
            isResponder: true,
            isDemo: true,
          ),
        ],
      DemoScenario.landslide => [
          VerificationVote(
            id: 'demo-vote-ls-1',
            incidentId: 'demo-ls-sos-001',
            reporterId: 'demo-responder-odraf-2',
            reporterName: 'DEMO · ODRAF coordinator',
            state: VerificationState.responderVerified,
            createdAt: now.subtract(const Duration(minutes: 8)),
            note: 'Synthetic scenario: drone visual confirmation.',
            isResponder: true,
            isDemo: true,
          ),
        ],
      DemoScenario.none => const [],
    };
  }

  List<RescueTeam> _teamsFor(DemoScenario scenario) {
    switch (scenario) {
      case DemoScenario.flood:
        return const [
          RescueTeam(
            id: 'demo-team-odraf',
            name: 'DEMO · ODRAF Boat Unit Alpha',
            latitude: 20.4620,
            longitude: 85.8720,
            unitType: 'Water rescue',
            status: 'available (synthetic)',
            capabilities: ['boat', 'swift-water', 'medical'],
            isDemo: true,
          ),
          RescueTeam(
            id: 'demo-team-ndrf',
            name: 'DEMO · NDRF Medical Bravo',
            latitude: 20.3010,
            longitude: 85.8300,
            unitType: 'Medical',
            status: 'on task (synthetic)',
            capabilities: ['medical', 'triage'],
            isDemo: true,
          ),
          RescueTeam(
            id: 'demo-team-fire',
            name: 'DEMO · Fire & Rescue Charlie',
            latitude: 20.4700,
            longitude: 85.8550,
            unitType: 'Fire / structural',
            status: 'available (synthetic)',
            capabilities: ['extrication', 'pump'],
            isDemo: true,
          ),
        ];
      case DemoScenario.earthquake:
        return const [
          RescueTeam(
            id: 'demo-team-ndrf-eq',
            name: 'DEMO · NDRF Search Unit 1',
            latitude: 20.3480,
            longitude: 85.8220,
            unitType: 'USAR',
            status: 'on task (synthetic)',
            capabilities: ['search', 'concrete-cutting', 'K9'],
            isDemo: true,
          ),
          RescueTeam(
            id: 'demo-team-med-eq',
            name: 'DEMO · Medical Triage Unit',
            latitude: 20.3420,
            longitude: 85.8250,
            unitType: 'Medical',
            status: 'available (synthetic)',
            capabilities: ['triage', 'ambulance'],
            isDemo: true,
          ),
          RescueTeam(
            id: 'demo-team-fire-eq',
            name: 'DEMO · Fire Unit Delta',
            latitude: 20.3500,
            longitude: 85.8180,
            unitType: 'Fire',
            status: 'on task (synthetic)',
            capabilities: ['fire suppression'],
            isDemo: true,
          ),
        ];
      case DemoScenario.landslide:
        return const [
          RescueTeam(
            id: 'demo-team-odraf-ls',
            name: 'DEMO · ODRAF Hill Rescue',
            latitude: 20.2480,
            longitude: 85.7900,
            unitType: 'Rope / USAR',
            status: 'en route (synthetic)',
            capabilities: ['rope rescue', 'cutting', 'medical'],
            isDemo: true,
          ),
          RescueTeam(
            id: 'demo-team-road-ls',
            name: 'DEMO · Road Clearance Unit',
            latitude: 20.2550,
            longitude: 85.8000,
            unitType: 'Engineering',
            status: 'available (synthetic)',
            capabilities: ['excavator', 'debris clearing'],
            isDemo: true,
          ),
        ];
      case DemoScenario.none:
        return const [];
    }
  }
}

extension on DemoContent {
  DemoContent copyWithTeams(List<RescueTeam> teams) => DemoContent(
        scenario: scenario,
        title: title,
        summary: summary,
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        rescueTeams: teams,
        topologyLabels: topologyLabels,
      );
}
