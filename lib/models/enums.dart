/// Shared, Flutter-independent domain enums for ResQMesh.
///
/// Wire values are stable and used in the mesh protocol and SQLite. They must
/// never be renamed without a protocol/database migration.
library;

enum IncidentKind {
  sos('sos'),
  hazard('hazard');

  const IncidentKind(this.wire);
  final String wire;

  static IncidentKind fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => IncidentKind.hazard,
      );
}

enum EmergencyCategory {
  flood('flood'),
  earthquake('earthquake'),
  landslide('landslide'),
  fire('fire'),
  collapsedBuilding('collapsed_building'),
  blockedRoad('blocked_road'),
  medical('medical'),
  infrastructure('infrastructure'),
  cyclone('cyclone'),
  other('other');

  const EmergencyCategory(this.wire);
  final String wire;

  static EmergencyCategory fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => EmergencyCategory.other,
      );

  bool get isHazard => this != EmergencyCategory.medical;
}

enum Severity {
  low('low', 1),
  moderate('moderate', 2),
  high('high', 3),
  critical('critical', 4);

  const Severity(this.wire, this.weight);
  final String wire;
  final int weight;

  static Severity fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => Severity.moderate,
      );
}

enum VerificationState {
  unverified('unverified'),
  communityCorroborated('community_corroborated'),
  responderVerified('responder_verified'),
  disputed('disputed'),
  expired('expired');

  const VerificationState(this.wire);
  final String wire;

  static VerificationState fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => VerificationState.unverified,
      );
}

enum IncidentStatus {
  active('active'),
  acknowledged('acknowledged'),
  responding('responding'),
  resolved('resolved'),
  closed('closed');

  const IncidentStatus(this.wire);
  final String wire;

  static IncidentStatus fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => IncidentStatus.active,
      );
}

enum ShelterStatus {
  open('open'),
  full('full'),
  closed('closed'),
  unknown('unknown');

  const ShelterStatus(this.wire);
  final String wire;

  static ShelterStatus fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => ShelterStatus.unknown,
      );
}

enum MeshMessageType {
  sos('sos'),
  hazard('hazard'),
  ack('ack'),
  shelterUpdate('shelter_update'),
  statusUpdate('status_update'),
  presence('presence'),
  text('text');

  const MeshMessageType(this.wire);
  final String wire;

  static MeshMessageType? tryFromWire(String? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }

  bool get isIncident => this == MeshMessageType.sos || this == MeshMessageType.hazard;
}

enum LocationSource {
  gps('gps'),
  manual('manual'),
  lastKnown('last_known'),
  meshRelay('mesh_relay'),
  computed('computed');

  const LocationSource(this.wire);
  final String wire;

  static LocationSource fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => LocationSource.manual,
      );
}

enum MeshDeliveryStatus {
  queued('queued'),
  transmitted('transmitted'),
  acknowledged('acknowledged'),
  failed('failed'),
  expired('expired');

  const MeshDeliveryStatus(this.wire);
  final String wire;

  static MeshDeliveryStatus fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => MeshDeliveryStatus.queued,
      );
}

enum RiskLevel {
  low('low'),
  moderate('moderate'),
  high('high'),
  severe('severe');

  const RiskLevel(this.wire);
  final String wire;

  static RiskLevel fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => RiskLevel.low,
      );
}

enum PriorityBand {
  critical('critical'),
  urgent('urgent'),
  elevated('elevated'),
  routine('routine');

  const PriorityBand(this.wire);
  final String wire;

  static PriorityBand fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => PriorityBand.routine,
      );
}

enum RiskTrend {
  increasing('increasing'),
  stable('stable'),
  decreasing('decreasing'),
  unknown('unknown');

  const RiskTrend(this.wire);
  final String wire;
}

enum AuditEventType {
  appStarted('app_started'),
  meshStarted('mesh_started'),
  meshStopped('mesh_stopped'),
  meshUnavailable('mesh_unavailable'),
  peerDiscovered('peer_discovered'),
  peerConnected('peer_connected'),
  peerDisconnected('peer_disconnected'),
  sosCreated('sos_created'),
  hazardCreated('hazard_created'),
  messageQueued('message_queued'),
  messageSent('message_sent'),
  messageReceived('message_received'),
  messageForwarded('message_forwarded'),
  messageAcknowledged('message_acknowledged'),
  duplicateDropped('duplicate_dropped'),
  invalidDropped('invalid_dropped'),
  rateLimited('rate_limited'),
  messageExpired('message_expired'),
  verificationChanged('verification_changed'),
  responderLogin('responder_login'),
  responderLoginFailed('responder_login_failed'),
  responderAction('responder_action'),
  shelterUpdated('shelter_updated'),
  locationUpdated('location_updated'),
  exportCreated('export_created'),
  settingChanged('setting_changed'),
  simulationRun('simulation_run'),
  demoSeeded('demo_seeded'),
  demoCleared('demo_cleared'),
  securityWarning('security_warning');

  const AuditEventType(this.wire);
  final String wire;

  static AuditEventType fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => AuditEventType.appStarted,
      );
}

enum DemoScenario {
  none('none'),
  flood('flood'),
  earthquake('earthquake'),
  landslide('landslide');

  const DemoScenario(this.wire);
  final String wire;

  static DemoScenario fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => DemoScenario.none,
      );
}

enum AppLanguage {
  english('en'),
  hindi('hi'),
  odia('or');

  const AppLanguage(this.code);
  final String code;

  static AppLanguage fromCode(String? code) => values.firstWhere(
        (e) => e.code == code,
        orElse: () => AppLanguage.english,
      );
}

/// Local role gate. This is deliberately NOT described as government identity
/// verification; it authenticates a responder session on this device only.
enum ResponderRole {
  volunteer('volunteer'),
  responder('responder'),
  coordinator('coordinator');

  const ResponderRole(this.wire);
  final String wire;
}

enum TransportKind {
  nearby('nearby'),
  simulated('simulated'),
  none('none');

  const TransportKind(this.wire);
  final String wire;

  static TransportKind fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => TransportKind.none,
      );
}

extension SeverityX on Severity {
  String get labelKey => 'severity_$wire';
}

extension CategoryX on EmergencyCategory {
  String get labelKey => 'category_$wire';
}

extension VerificationX on VerificationState {
  String get labelKey => 'verification_$wire';
}

extension IncidentStatusX on IncidentStatus {
  String get labelKey => 'status_$wire';
}

extension ShelterStatusX on ShelterStatus {
  String get labelKey => 'shelter_status_$wire';
}

extension PriorityBandX on PriorityBand {
  String get labelKey => 'priority_$wire';
}

extension RiskLevelX on RiskLevel {
  String get labelKey => 'risk_$wire';
}

extension DemoScenarioX on DemoScenario {
  String get labelKey => 'scenario_$wire';
}
