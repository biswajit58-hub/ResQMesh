import 'enums.dart';
import 'geo_fix.dart';

class Incident {
  const Incident({
    required this.id,
    required this.kind,
    required this.category,
    required this.severity,
    required this.peopleAffected,
    required this.description,
    required this.location,
    required this.status,
    required this.verification,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.originId,
    required this.originName,
    this.meshMessageId,
    this.relayCount = 0,
    this.receiptCount = 0,
    this.independentReporters = 1,
    this.isDemo = false,
    this.synthetic = false,
  });

  final String id;
  final String? meshMessageId;
  final IncidentKind kind;
  final EmergencyCategory category;
  final Severity severity;
  final int peopleAffected;
  final String description;
  final GeoFix location;
  final IncidentStatus status;
  final VerificationState verification;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final String originId;
  final String originName;
  final int relayCount;
  final int receiptCount;

  /// Count of independently authored reports that support this incident. A
  /// forwarded copy of the same message is never counted.
  final int independentReporters;
  final bool isDemo;

  /// True only for generated scenario data; always rendered with a demo badge.
  final bool synthetic;

  bool get isExpired =>
      DateTime.now().toUtc().isAfter(expiresAt.toUtc()) ||
      verification == VerificationState.expired;

  String get shortTitle {
    final suffix = description.trim().isEmpty
        ? ''
        : ' — ${description.trim().split('\n').first}';
    return '${category.wire.replaceAll('_', ' ')}$suffix';
  }

  Incident copyWith({
    String? meshMessageId,
    Severity? severity,
    int? peopleAffected,
    String? description,
    GeoFix? location,
    IncidentStatus? status,
    VerificationState? verification,
    DateTime? updatedAt,
    DateTime? expiresAt,
    int? relayCount,
    int? receiptCount,
    int? independentReporters,
    bool? isDemo,
  }) =>
      Incident(
        id: id,
        kind: kind,
        category: category,
        severity: severity ?? this.severity,
        peopleAffected: peopleAffected ?? this.peopleAffected,
        description: description ?? this.description,
        location: location ?? this.location,
        status: status ?? this.status,
        verification: verification ?? this.verification,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        originId: originId,
        originName: originName,
        meshMessageId: meshMessageId ?? this.meshMessageId,
        relayCount: relayCount ?? this.relayCount,
        receiptCount: receiptCount ?? this.receiptCount,
        independentReporters:
            independentReporters ?? this.independentReporters,
        isDemo: isDemo ?? this.isDemo,
        synthetic: synthetic,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'mesh_message_id': meshMessageId,
        'kind': kind.wire,
        'category': category.wire,
        'severity': severity.wire,
        'people_affected': peopleAffected,
        'description': description,
        'lat': location.latitude,
        'lng': location.longitude,
        'accuracy_m': location.accuracyMeters,
        'location_source': location.source.wire,
        'location_ts': location.capturedAt.toUtc().millisecondsSinceEpoch,
        'location_description': location.description,
        'status': status.wire,
        'verification': verification.wire,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
        'expires_at': expiresAt.toUtc().millisecondsSinceEpoch,
        'origin_id': originId,
        'origin_name': originName,
        'relay_count': relayCount,
        'receipt_count': receiptCount,
        'independent_reporters': independentReporters,
        'is_demo': isDemo ? 1 : 0,
        'synthetic': synthetic ? 1 : 0,
      };

  factory Incident.fromMap(Map<String, Object?> map) {
    final lat = (map['lat'] as num?)?.toDouble() ?? 0;
    final lng = (map['lng'] as num?)?.toDouble() ?? 0;
    return Incident(
      id: map['id'] as String,
      meshMessageId: map['mesh_message_id'] as String?,
      kind: IncidentKind.fromWire(map['kind'] as String?),
      category: EmergencyCategory.fromWire(map['category'] as String?),
      severity: Severity.fromWire(map['severity'] as String?),
      peopleAffected: (map['people_affected'] as num?)?.toInt() ?? 0,
      description: map['description'] as String? ?? '',
      location: GeoFix(
        latitude: lat,
        longitude: lng,
        accuracyMeters: (map['accuracy_m'] as num?)?.toDouble() ?? 1000,
        source: LocationSource.fromWire(map['location_source'] as String?),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['location_ts'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        description: map['location_description'] as String? ?? '',
      ),
      status: IncidentStatus.fromWire(map['status'] as String?),
      verification: VerificationState.fromWire(map['verification'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (map['expires_at'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
      originId: map['origin_id'] as String? ?? '',
      originName: map['origin_name'] as String? ?? 'Unknown device',
      relayCount: (map['relay_count'] as num?)?.toInt() ?? 0,
      receiptCount: (map['receipt_count'] as num?)?.toInt() ?? 0,
      independentReporters:
          (map['independent_reporters'] as num?)?.toInt() ?? 1,
      isDemo: ((map['is_demo'] as num?)?.toInt() ?? 0) == 1,
      synthetic: ((map['synthetic'] as num?)?.toInt() ?? 0) == 1,
    );
  }
}
