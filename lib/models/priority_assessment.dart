import 'enums.dart';

class PriorityFactor {
  const PriorityFactor({
    required this.code,
    required this.label,
    required this.points,
    required this.maxPoints,
    required this.detail,
  });

  final String code;
  final String label;
  final double points;
  final double maxPoints;
  final String detail;

  Map<String, Object?> toJson() => {
        'code': code,
        'label': label,
        'points': points,
        'maxPoints': maxPoints,
        'detail': detail,
      };
}

class PriorityAssessment {
  const PriorityAssessment({
    required this.incidentId,
    required this.score,
    required this.band,
    required this.factors,
    required this.explanation,
    required this.recommendedAction,
    required this.computedAt,
    required this.waitingMinutes,
    this.responderDistanceKm,
    this.factorCoverage = 1,
  });

  final String incidentId;
  final double score;
  final PriorityBand band;
  final List<PriorityFactor> factors;
  final String explanation;
  final String recommendedAction;
  final DateTime computedAt;
  final int waitingMinutes;
  final double? responderDistanceKm;

  /// Fraction of the theoretical factor weight that could be observed. When
  /// responder positions are unavailable this is below 1.0 and the UI says so.
  final double factorCoverage;
}
