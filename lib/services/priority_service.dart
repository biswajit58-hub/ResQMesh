import 'dart:math' as math;

import '../models/enums.dart';
import '../models/incident.dart';
import '../models/priority_assessment.dart';
import '../models/rescue_team.dart';

/// Transparent rescue-priority scoring for human responders.
///
/// Factor weights sum to 100. If responder positions are unavailable the
/// proximity factor is 0/5 and [PriorityAssessment.factorCoverage] is 0.95; the
/// UI must display that missing input rather than invent one.
class PriorityService {
  const PriorityService();

  List<PriorityAssessment> rank({
    required List<Incident> incidents,
    required List<RescueTeam> rescueTeams,
    DateTime? now,
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    final assessments = incidents
        .where((incident) =>
            !incident.isExpired &&
            incident.status != IncidentStatus.resolved &&
            incident.status != IncidentStatus.closed)
        .map((incident) => assess(
              incident: incident,
              rescueTeams: rescueTeams,
              now: clock,
            ))
        .toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));
    return assessments;
  }

  PriorityAssessment assess({
    required Incident incident,
    required List<RescueTeam> rescueTeams,
    DateTime? now,
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    final waitingMinutes = math.max(
      0,
      clock.difference(incident.createdAt.toUtc()).inMinutes,
    );

    final severityPoints = switch (incident.severity) {
      Severity.critical => 40.0,
      Severity.high => 31.0,
      Severity.moderate => 20.0,
      Severity.low => 10.0,
    };
    final people = incident.peopleAffected;
    final peoplePoints = people <= 0
        ? 0.0
        : people == 1
            ? 5.0
            : people <= 5
                ? 11.0
                : people <= 15
                    ? 17.0
                    : people <= 50
                        ? 22.0
                        : 25.0;
    final waitingPoints = math.min(15.0, waitingMinutes / 32.0);
    final reliabilityPoints = switch (incident.verification) {
      VerificationState.responderVerified => 10.0,
      VerificationState.communityCorroborated => 7.0,
      VerificationState.unverified => 2.0,
      VerificationState.disputed => 0.0,
      VerificationState.expired => 0.0,
    };
    final accuracy = incident.location.accuracyMeters;
    final sourcePenalty = switch (incident.location.source) {
      LocationSource.gps => 1.0,
      LocationSource.manual => 0.8,
      LocationSource.meshRelay => 0.8,
      LocationSource.lastKnown => 0.5,
      LocationSource.computed => 0.3,
    };
    final locationPoints = (accuracy <= 25
            ? 5.0
            : accuracy <= 100
                ? 4.0
                : accuracy <= 500
                    ? 2.5
                    : 1.0) *
        sourcePenalty;

    RescueTeam? nearest;
    var nearestKm = double.infinity;
    for (final team in rescueTeams) {
      final km = incident.location.distanceMetersTo(
            incident.location.copyWith(
              latitude: team.latitude,
              longitude: team.longitude,
            ),
          ) /
          1000;
      if (km < nearestKm) {
        nearestKm = km;
        nearest = team;
      }
    }
    final hasResponders = nearest != null && nearestKm.isFinite;
    final proximityPoints = !hasResponders
        ? 0.0
        : nearestKm <= 2
            ? 5.0
            : nearestKm <= 5
                ? 4.0
                : nearestKm <= 10
                    ? 2.5
                    : 1.0;

    final factors = <PriorityFactor>[
      PriorityFactor(
        code: 'severity',
        label: 'Danger severity',
        points: severityPoints,
        maxPoints: 40,
        detail:
            'Reported ${incident.severity.wire} severity. This is the largest weight.',
      ),
      PriorityFactor(
        code: 'people',
        label: 'People affected',
        points: peoplePoints,
        maxPoints: 25,
        detail: '$people person(s) reported as needing assistance.',
      ),
      PriorityFactor(
        code: 'waiting',
        label: 'Waiting time',
        points: waitingPoints,
        maxPoints: 15,
        detail: 'Waiting approximately $waitingMinutes minute(s) since the report was created.',
      ),
      PriorityFactor(
        code: 'reliability',
        label: 'Report reliability',
        points: reliabilityPoints,
        maxPoints: 10,
        detail:
            'Verification state: ${incident.verification.wire}. Forward count is not treated as corroboration.',
      ),
      PriorityFactor(
        code: 'location',
        label: 'Location confidence',
        points: locationPoints,
        maxPoints: 5,
        detail:
            '±${accuracy.round()} m from ${incident.location.source.wire}; older saved locations score lower.',
      ),
      PriorityFactor(
        code: 'proximity',
        label: 'Responder proximity',
        points: proximityPoints,
        maxPoints: 5,
        detail: hasResponders
            ? 'Nearest known team: ${nearest.name} at ${nearestKm.toStringAsFixed(1)} km.${nearest.isDemo ? ' Demo team position — not live GPS.' : ''}'
            : 'No responder position is available on this offline device; factor left at 0 instead of being guessed.',
      ),
    ];

    final score = factors.fold<double>(0, (sum, factor) => sum + factor.points);
    final band = score >= 75
        ? PriorityBand.critical
        : score >= 55
            ? PriorityBand.urgent
            : score >= 35
                ? PriorityBand.elevated
                : PriorityBand.routine;
    final coverage = hasResponders ? 1.0 : 0.95;
    final explanation =
        'Score ${score.toStringAsFixed(1)}/100 from ${factors.length} transparent factors. '
        '${hasResponders ? 'Responder proximity is based on locally known team positions.' : 'Responder proximity was unavailable and contributed 0 points.'} '
        'This is a decision aid, not an order.';
    final recommended = switch (band) {
      PriorityBand.critical =>
        'Human coordinator review recommended immediately. Check accessibility and dispatch the nearest appropriate capability.',
      PriorityBand.urgent =>
        'Review within the current response cycle and confirm the report through an independent source.',
      PriorityBand.elevated =>
        'Queue for review; reassess if new corroborating reports or severity changes arrive.',
      PriorityBand.routine =>
        'Monitor. Lower immediate danger based on available reports.',
    };

    return PriorityAssessment(
      incidentId: incident.id,
      score: score.clamp(0, 100).toDouble(),
      band: band,
      factors: factors,
      explanation: explanation,
      recommendedAction: recommended,
      computedAt: clock,
      waitingMinutes: waitingMinutes,
      responderDistanceKm: hasResponders ? nearestKm : null,
      factorCoverage: coverage,
    );
  }
}
