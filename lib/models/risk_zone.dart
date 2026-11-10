import 'enums.dart';
import 'geo_fix.dart';

class RiskFactor {
  const RiskFactor({
    required this.code,
    required this.label,
    required this.contribution,
    required this.detail,
  });

  final String code;
  final String label;
  final double contribution;
  final String detail;

  Map<String, Object?> toJson() => {
        'code': code,
        'label': label,
        'contribution': contribution,
        'detail': detail,
      };

  factory RiskFactor.fromJson(Map<String, dynamic> json) => RiskFactor(
        code: json['code'] as String? ?? '',
        label: json['label'] as String? ?? '',
        contribution: (json['contribution'] as num?)?.toDouble() ?? 0,
        detail: json['detail'] as String? ?? '',
      );
}

/// A spatial cluster of separately authored hazard reports.
///
/// [observedCount] is an observation; [score] is an estimate from the visible
/// rule engine. They must be labelled differently in the UI.
class RiskZone {
  const RiskZone({
    required this.id,
    required this.center,
    required this.radiusMeters,
    required this.category,
    required this.score,
    required this.level,
    required this.observedCount,
    required this.independentReporters,
    required this.factors,
    required this.incidentIds,
    required this.trend,
    required this.updatedAt,
    required this.isDemo,
  });

  final String id;
  final GeoFix center;
  final double radiusMeters;
  final EmergencyCategory category;
  final double score;
  final RiskLevel level;
  final int observedCount;
  final int independentReporters;
  final List<RiskFactor> factors;
  final List<String> incidentIds;
  final RiskTrend trend;
  final DateTime updatedAt;
  final bool isDemo;

  bool get isEstimated => true;
}
