import 'dart:math' as math;

import 'enums.dart';

/// A location observation with provenance.
///
/// ResQMesh never presents [LocationSource.lastKnown] or an old timestamp as a
/// live GPS fix. [isLive] requires a fresh GPS observation.
class GeoFix {
  const GeoFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.source,
    required this.capturedAt,
    this.description = '',
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final LocationSource source;
  final DateTime capturedAt;
  final String description;

  bool get isFresh =>
      DateTime.now().toUtc().difference(capturedAt.toUtc()).inMinutes < 2;

  bool get isLive => isFresh && source == LocationSource.gps;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      accuracyMeters.isFinite &&
      accuracyMeters >= 0;

  String get uncertaintyLabel {
    if (accuracyMeters <= 15) return 'high';
    if (accuracyMeters <= 75) return 'medium';
    return 'low';
  }

  double distanceMetersTo(GeoFix other) {
    const earthRadius = 6371000.0;
    final dLat = _rad(other.latitude - latitude);
    final dLng = _rad(other.longitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(latitude)) *
            math.cos(_rad(other.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  GeoFix copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    LocationSource? source,
    DateTime? capturedAt,
    String? description,
  }) =>
      GeoFix(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        accuracyMeters: accuracyMeters ?? this.accuracyMeters,
        source: source ?? this.source,
        capturedAt: capturedAt ?? this.capturedAt,
        description: description ?? this.description,
      );

  Map<String, Object?> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'acc': accuracyMeters,
        'src': source.wire,
        'ts': capturedAt.toUtc().millisecondsSinceEpoch,
        if (description.isNotEmpty) 'desc': description,
      };

  factory GeoFix.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw const FormatException('Location missing lat/lng');
    }
    return GeoFix(
      latitude: lat,
      longitude: lng,
      accuracyMeters: (json['acc'] as num?)?.toDouble() ?? 1000,
      source: LocationSource.fromWire(json['src'] as String?),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['ts'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
      description: (json['desc'] as String? ?? '').trim(),
    );
  }

  @override
  String toString() =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)} (±${accuracyMeters.round()}m, ${source.wire})';
}
