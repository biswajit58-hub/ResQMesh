import '../../models/enums.dart';

class IncidentReportPayload {
  const IncidentReportPayload({
    required this.category,
    required this.severity,
    required this.peopleAffected,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.locationSource,
    required this.locationTimestamp,
    required this.createdAt,
    this.locationDescription = '',
    this.description = '',
  });

  final EmergencyCategory category;
  final Severity severity;
  final int peopleAffected;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final LocationSource locationSource;
  final DateTime locationTimestamp;
  final DateTime createdAt;
  final String locationDescription;
  final String description;

  Map<String, Object?> toJson() => {
        'category': category.wire,
        'severity': severity.wire,
        'people': peopleAffected,
        'lat': latitude,
        'lng': longitude,
        'accuracy': accuracyMeters,
        'locationSource': locationSource.wire,
        'locationTs': locationTimestamp.toUtc().millisecondsSinceEpoch,
        'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
        if (locationDescription.isNotEmpty)
          'locationDescription': locationDescription,
        if (description.isNotEmpty) 'description': description,
      };

  factory IncidentReportPayload.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      throw const FormatException('Invalid incident coordinates');
    }
    final people = (json['people'] as num?)?.toInt() ?? 1;
    if (people < 0 || people > 100000) {
      throw const FormatException('Invalid people count');
    }
    final description = (json['description'] as String? ?? '').trim();
    final locationDescription =
        (json['locationDescription'] as String? ?? '').trim();
    if (description.length > 2000 || locationDescription.length > 500) {
      throw const FormatException('Incident text exceeds limit');
    }
    return IncidentReportPayload(
      category: EmergencyCategory.fromWire(json['category'] as String?),
      severity: Severity.fromWire(json['severity'] as String?),
      peopleAffected: people,
      latitude: lat,
      longitude: lng,
      accuracyMeters: ((json['accuracy'] as num?)?.toDouble() ?? 1000)
          .clamp(0, 100000)
          .toDouble(),
      locationSource: LocationSource.fromWire(json['locationSource'] as String?),
      locationTimestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['locationTs'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
      locationDescription: locationDescription,
      description: description,
    );
  }
}

class AckPayload {
  const AckPayload({
    required this.ackFor,
    required this.targetDeviceId,
    required this.receiverId,
    required this.receiverName,
    required this.receivedAt,
  });

  final String ackFor;
  final String targetDeviceId;
  final String receiverId;
  final String receiverName;
  final DateTime receivedAt;

  Map<String, Object?> toJson() => {
        'ackFor': ackFor,
        'target': targetDeviceId,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receivedAt': receivedAt.toUtc().millisecondsSinceEpoch,
      };

  factory AckPayload.fromJson(Map<String, dynamic> json) {
    final ackFor = json['ackFor'] as String? ?? '';
    final target = json['target'] as String? ?? '';
    if (ackFor.length < 8 || ackFor.length > 80) {
      throw const FormatException('Invalid acknowledgement reference');
    }
    if (target.length < 8 || target.length > 80) {
      throw const FormatException('Invalid acknowledgement target');
    }
    return AckPayload(
      ackFor: ackFor,
      targetDeviceId: target,
      receiverId: json['receiverId'] as String? ?? '',
      receiverName: json['receiverName'] as String? ?? 'Peer',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['receivedAt'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
    );
  }
}

int priorityFor(Severity severity, {int peopleAffected = 1}) {
  final base = switch (severity) {
    Severity.critical => 9,
    Severity.high => 8,
    Severity.moderate => 6,
    Severity.low => 4,
  };
  if (peopleAffected >= 10) return (base + 1).clamp(0, 9);
  return base;
}
