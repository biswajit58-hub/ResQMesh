import 'dart:math' as math;

import '../models/enums.dart';
import '../models/incident.dart';
import '../models/verification_vote.dart';

class VerificationResult {
  const VerificationResult({
    required this.state,
    required this.independentReporters,
    required this.explanation,
    required this.corroboratingIncidentIds,
    required this.disputeVotes,
  });

  final VerificationState state;
  final int independentReporters;
  final String explanation;
  final List<String> corroboratingIncidentIds;
  final int disputeVotes;
}

/// Crowd verification with an explicit anti-ballot-stuffing rule:
/// * Only separately authored incidents with distinct origin IDs count.
/// * Relayed copies share the same message ID and never reach this method.
/// * A device cannot verify its own report.
/// * Responder verification requires an authenticated local responder session.
class VerificationService {
  const VerificationService({
    this.radiusMeters = 450,
    this.window = const Duration(minutes: 90),
    this.corroborationThreshold = 2,
    this.disputeThreshold = 2,
  });

  final double radiusMeters;
  final Duration window;
  final int corroborationThreshold;
  final int disputeThreshold;

  VerificationResult evaluate({
    required Incident incident,
    required List<Incident> allIncidents,
    required List<VerificationVote> votes,
    DateTime? now,
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    if (clock.isAfter(incident.expiresAt.toUtc())) {
      return VerificationResult(
        state: VerificationState.expired,
        independentReporters: 1,
        explanation: 'This report passed its 12-hour expiry window.',
        corroboratingIncidentIds: const [],
        disputeVotes: 0,
      );
    }

    final origins = <String>{incident.originId};
    final corroborating = <String>[];
    for (final other in allIncidents) {
      if (other.id == incident.id) continue;
      if (other.isExpired) continue;
      if (other.verification == VerificationState.disputed) continue;
      if (other.isDemo != incident.isDemo) continue;
      if (other.category != incident.category) continue;
      if (other.originId == incident.originId) continue;
      if (origins.contains(other.originId)) continue;
      final gap = other.createdAt.toUtc().difference(incident.createdAt.toUtc());
      if (gap.abs() > window) continue;
      if (other.location.distanceMetersTo(incident.location) > radiusMeters) {
        continue;
      }
      origins.add(other.originId);
      corroborating.add(other.id);
    }
    final independent = origins.length;

    final independentDisputes = <String>{};
    var responderVerified = false;
    var responderDisputed = false;
    for (final vote in votes) {
      if (vote.reporterId == incident.originId) continue;
      if (vote.state == VerificationState.responderVerified) {
        if (vote.isResponder) responderVerified = true;
      } else if (vote.state == VerificationState.disputed) {
        independentDisputes.add(vote.reporterId);
        if (vote.isResponder) responderDisputed = true;
      }
    }

    if (responderVerified) {
      return VerificationResult(
        state: VerificationState.responderVerified,
        independentReporters: independent,
        explanation:
            'A locally authenticated responder marked this report verified. Responder identity is a local role gate, not a government credential check.',
        corroboratingIncidentIds: corroborating,
        disputeVotes: independentDisputes.length,
      );
    }
    if (responderDisputed ||
        independentDisputes.length >= disputeThreshold) {
      return VerificationResult(
        state: VerificationState.disputed,
        independentReporters: independent,
        explanation:
            '${math.max(independentDisputes.length, responderDisputed ? 1 : 0)} independent dispute vote(s) outweigh current corroboration. Forwarded copies were not counted.',
        corroboratingIncidentIds: corroborating,
        disputeVotes: independentDisputes.length,
      );
    }
    if (independent >= corroborationThreshold) {
      return VerificationResult(
        state: VerificationState.communityCorroborated,
        independentReporters: independent,
        explanation:
            '$independent separately authored reports from distinct devices agree within ${radiusMeters.round()} m and ${window.inMinutes} minutes. Forwarded copies do not count.',
        corroboratingIncidentIds: corroborating,
        disputeVotes: independentDisputes.length,
      );
    }
    return VerificationResult(
      state: VerificationState.unverified,
      independentReporters: independent,
      explanation:
          'Only $independent independent report(s) currently support this incident. Corroboration needs $corroborationThreshold distinct origin devices.',
      corroboratingIncidentIds: corroborating,
      disputeVotes: independentDisputes.length,
    );
  }
}
