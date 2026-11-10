import 'dart:math' as math;

import '../models/enums.dart';
import '../models/geo_fix.dart';
import '../models/incident.dart';
import '../models/risk_zone.dart';

/// Transparent, deterministic local hazard analytics.
///
/// This is a rule engine, not a trained model and not a source of environmental
/// measurements. Every score is an estimate derived solely from local reports.
class IntelligenceService {
  const IntelligenceService({
    this.clusterRadiusMeters = 1100,
    this.clusterWindow = const Duration(hours: 6),
  });

  final double clusterRadiusMeters;
  final Duration clusterWindow;

  List<RiskZone> analyze(List<Incident> incidents, {DateTime? now}) {
    final clock = (now ?? DateTime.now()).toUtc();
    final hazards = incidents
        .where((incident) =>
            incident.kind == IncidentKind.hazard &&
            !incident.isExpired &&
            incident.status != IncidentStatus.resolved &&
            incident.status != IncidentStatus.closed)
        .toList(growable: false);
    if (hazards.isEmpty) return const [];

    final byCategory = <EmergencyCategory, List<Incident>>{};
    for (final incident in hazards) {
      byCategory.putIfAbsent(incident.category, () => []).add(incident);
    }

    final zones = <RiskZone>[];
    byCategory.forEach((category, categoryIncidents) {
      final clusters = <List<Incident>>[];
      for (final incident in categoryIncidents) {
        List<Incident>? best;
        for (final cluster in clusters) {
          final anchor = cluster.first;
          final span = incident.createdAt
              .toUtc()
              .difference(anchor.createdAt.toUtc())
              .abs();
          if (span > clusterWindow) continue;
          if (incident.location.distanceMetersTo(anchor.location) <=
              clusterRadiusMeters) {
            best = cluster;
            break;
          }
        }
        if (best == null) {
          clusters.add([incident]);
        } else {
          best.add(incident);
        }
      }
      for (final cluster in clusters) {
        zones.add(_scoreCluster(
          category,
          cluster,
          clock,
        ));
      }
    });
    zones.sort((a, b) => b.score.compareTo(a.score));
    return zones;
  }

  RiskZone _scoreCluster(
    EmergencyCategory category,
    List<Incident> cluster,
    DateTime now,
  ) {
    final lat =
        cluster.map((e) => e.location.latitude).reduce((a, b) => a + b) /
            cluster.length;
    final lng =
        cluster.map((e) => e.location.longitude).reduce((a, b) => a + b) /
            cluster.length;
    final center = GeoFix(
      latitude: lat,
      longitude: lng,
      accuracyMeters: 250,
      source: LocationSource.computed,
      capturedAt: now,
      description: 'Estimated cluster centroid',
    );

    final origins = cluster.map((e) => e.originId).toSet();
    var maxDistance = 0.0;
    for (final incident in cluster) {
      final distance = center.distanceMetersTo(incident.location);
      if (distance > maxDistance) maxDistance = distance;
    }
    final radius = (maxDistance + 250).clamp(300, 2500).toDouble();

    final uniqueOrigins = origins.length;
    final observed = cluster.length;
    final maxSeverity = cluster
        .map((e) => e.severity.weight)
        .reduce((a, b) => math.max(a, b));
    final latest = cluster
        .map((e) => e.createdAt.toUtc())
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final ageMinutes = math.max(0, now.difference(latest).inMinutes);
    final oneHourAgo = now.subtract(const Duration(minutes: 30));
    final twoHoursAgo = now.subtract(const Duration(minutes: 60));
    final recentCount =
        cluster.where((e) => e.createdAt.toUtc().isAfter(oneHourAgo)).length;
    final previousCount = cluster
        .where((e) =>
            e.createdAt.toUtc().isAfter(twoHoursAgo) &&
            !e.createdAt.toUtc().isAfter(oneHourAgo))
        .length;
    final trend = recentCount > previousCount
        ? RiskTrend.increasing
        : recentCount < previousCount
            ? RiskTrend.decreasing
            : RiskTrend.stable;

    final verifiedCount = cluster
        .where((e) =>
            e.verification == VerificationState.responderVerified ||
            e.verification == VerificationState.communityCorroborated)
        .length;
    final disputedCount = cluster
        .where((e) => e.verification == VerificationState.disputed)
        .length;

    final factors = <RiskFactor>[];
    final categoryWeight = switch (category) {
      EmergencyCategory.collapsedBuilding => 1.15,
      EmergencyCategory.earthquake => 1.15,
      EmergencyCategory.landslide => 1.1,
      EmergencyCategory.fire => 1.05,
      EmergencyCategory.cyclone => 1.1,
      _ => 1.0,
    };
    final countContribution =
        math.min(28.0, (uniqueOrigins * 8.0) + math.max(0, observed - uniqueOrigins) * 2.0);
    factors.add(RiskFactor(
      code: 'independent_reports',
      label: 'Independent report concentration',
      contribution: countContribution,
      detail:
          '$uniqueOrigins independent origin(s); $observed total report(s). Forwarded copies do not inflate this factor.',
    ));
    final severityContribution = (maxSeverity / 4) * 30 * categoryWeight;
    factors.add(RiskFactor(
      code: 'severity',
      label: 'Maximum observed severity',
      contribution: severityContribution,
      detail:
          'Highest reported severity is ${maxSeverity == 4 ? 'critical' : maxSeverity == 3 ? 'high' : maxSeverity == 2 ? 'moderate' : 'low'}. Category multiplier ${categoryWeight.toStringAsFixed(2)}.',
    ));
    final verificationContribution = verifiedCount > 0
        ? math.min(16.0, verifiedCount * 8.0)
        : disputedCount > 0
            ? -8.0
            : 0.0;
    factors.add(RiskFactor(
      code: 'verification',
      label: 'Verification signal',
      contribution: verificationContribution,
      detail: verifiedCount > 0
          ? '$verifiedCount report(s) are community-corroborated or responder-verified.'
          : disputedCount > 0
              ? '$disputedCount report(s) are disputed; confidence reduced.'
              : 'Reports are currently unverified. No credibility credit applied.',
    ));
    final recencyContribution = ageMinutes <= 30
        ? 14.0
        : ageMinutes <= 120
            ? 9.0
            : ageMinutes <= 360
                ? 4.0
                : 0.0;
    factors.add(RiskFactor(
      code: 'recency',
      label: 'Report recency',
      contribution: recencyContribution,
      detail: 'Newest report is $ageMinutes minute(s) old.',
    ));
    final trendContribution = trend == RiskTrend.increasing ? 8.0 : 0.0;
    factors.add(RiskFactor(
      code: 'trend',
      label: 'Recent report trend',
      contribution: trendContribution,
      detail:
          '$recentCount report(s) in the last 30 min vs $previousCount in the prior 30 min.',
    ));
    final spreadContribution = radius > 900 ? 4.0 : 2.0;
    factors.add(RiskFactor(
      code: 'spread',
      label: 'Geographic spread',
      contribution: spreadContribution,
      detail:
          'Cluster spans about ${radius.round()} m. A wider cluster may indicate an area-wide hazard.',
    ));

    final rawScore = factors.fold<double>(0, (sum, f) => sum + f.contribution);
    final score = rawScore.clamp(0, 100).toDouble();
    final level = score >= 75
        ? RiskLevel.severe
        : score >= 55
            ? RiskLevel.high
            : score >= 35
                ? RiskLevel.moderate
                : RiskLevel.low;

    return RiskZone(
      id:
          'zone_${category.wire}_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}',
      center: center,
      radiusMeters: radius,
      category: category,
      score: score,
      level: level,
      observedCount: observed,
      independentReporters: uniqueOrigins,
      factors: factors,
      incidentIds: cluster.map((e) => e.id).toList(growable: false),
      trend: trend,
      updatedAt: now,
      isDemo: cluster.every((e) => e.isDemo),
    );
  }
}
