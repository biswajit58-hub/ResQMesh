import 'geo_fix.dart';
import 'shelter.dart';

class EvacuationRoute {
  const EvacuationRoute({
    required this.id,
    required this.origin,
    required this.shelter,
    required this.waypoints,
    required this.distanceMeters,
    required this.estimatedMinutes,
    required this.warnings,
    required this.generatedAt,
    required this.hazardsConsidered,
    required this.dataAgeMinutes,
  });

  final String id;
  final GeoFix origin;
  final Shelter shelter;
  final List<GeoFix> waypoints;
  final double distanceMeters;
  final int estimatedMinutes;
  final List<String> warnings;
  final DateTime generatedAt;
  final int hazardsConsidered;
  final int dataAgeMinutes;

  bool get isDataStale => dataAgeMinutes > 120;

  /// Never true. ResQMesh route guidance is advisory because reports are
  /// incomplete and conditions change.
  bool get isGuaranteedSafe => false;
}

class EvacuationResult {
  const EvacuationResult({this.route, this.error});
  final EvacuationRoute? route;
  final String? error;

  bool get isSuccess => route != null;
}
