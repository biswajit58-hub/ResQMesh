import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/status_styles.dart';
import '../../core/utilities/formatters.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../models/message_record.dart';
import '../../models/priority_assessment.dart';
import '../../models/risk_zone.dart';
import '../../services/app_state.dart';
import '../../services/verification_service.dart';
import '../../widgets/background.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/offline_map_view.dart';
import '../responder/responder_dashboard_screen.dart';

class IncidentDetailScreen extends StatefulWidget {
  const IncidentDetailScreen({super.key, required this.incident});
  final Incident incident;

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  bool _busy = false;

  Incident _incident(AppState state) => state.incidents
          .firstWhereOrNull((e) => e.id == widget.incident.id) ??
      widget.incident;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final incident = _incident(state);
    final priority = state.assessmentFor(incident.id);
    final zone = state.zoneForIncident(incident.id);
    final evidence = state.verificationEvidence[incident.id];
    final message = state.messages.firstWhereOrNull(
      (m) => m.id == incident.id,
    );
    return PageScaffold(
      title: context.tr('incident_title'),
      subtitle: shortId(incident.id),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_busy) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),
            ],
            if (incident.isDemo) ...[
              const DemoBanner(compact: true),
              const SizedBox(height: 10),
            ],
            _Hero(incident: incident, priority: priority),
            const SizedBox(height: 12),
            _LocationCard(incident: incident),
            const SizedBox(height: 12),
            if (priority != null) ...[
              _PriorityCard(incident: incident, priority: priority),
              const SizedBox(height: 12),
            ],
            _VerificationCard(
              incident: incident,
              evidence: evidence,
              isResponder: state.isResponder,
              onOpenResponder: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ResponderDashboardScreen(),
                ),
              ),
              onVerify: () => _responderVote(
                state,
                incident,
                VerificationState.responderVerified,
              ),
              onDispute: () => _responderVote(
                state,
                incident,
                VerificationState.disputed,
              ),
              onCorroborate: () => _corroborate(state, incident),
              isOwn: incident.originId == state.deviceId,
            ),
            const SizedBox(height: 12),
            if (zone != null) ...[
              _RiskZoneCard(zone: zone),
              const SizedBox(height: 12),
            ],
            _RelayCard(incident: incident, message: message),
            const SizedBox(height: 12),
            _StatusActions(state: state, incident: incident),
            const SizedBox(height: 12),
            _TimelineCard(state: state, incident: incident),
            const SizedBox(height: 12),
            const InfoBanner(
              icon: Icons.gavel_rounded,
              color: AppColors.amber,
              title: 'HUMAN OVERSIGHT',
              message:
                  'Scores, verification labels and route guidance are decision support only. Responders remain responsible for safety and dispatch decisions.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _responderVote(
    AppState state,
    Incident incident,
    VerificationState voteState,
  ) async {
    if (!state.isResponder) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('responder_required'))),
      );
      return;
    }
    final note = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('verification_action')),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.tr('responder_note'),
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
    if (submit != true) {
      note.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      await state.addResponderVote(
        incidentId: incident.id,
        state: voteState,
        note: note.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(voteState.wire)),
        );
      }
    } finally {
      note.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _corroborate(AppState state, Incident incident) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('corroborate')),
        content: const Text(
          'This creates a NEW observation from your current location. It counts as independent confirmation only if you are within 450 m and 90 minutes of the original report. Forwarding alone never counts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final result = await state.corroborateIncident(incident);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.incident, this.priority});
  final Incident incident;
  final PriorityAssessment? priority;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(incident.category);
    return GlowSurface(
      accent: incident.kind == IncidentKind.sos ? AppColors.red : color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(categoryIcon(incident.category),
                    color: color, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr(incident.category.labelKey),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        if (incident.isDemo) const DemoBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${incident.kind.wire.toUpperCase()} · ${shortId(incident.id)}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              if (priority != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: priorityColor(priority!.band).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: priorityColor(priority!.band)
                          .withValues(alpha: 0.32),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        priority!.score.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 16,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: priorityColor(priority!.band),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('score'),
                        style: const TextStyle(
                          fontSize: 7,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(
                label: context.tr(incident.severity.labelKey),
                color: severityColor(incident.severity),
                icon: Icons.warning_rounded,
              ),
              StatusPill(
                label: context.tr(incident.verification.labelKey),
                color: verificationColor(incident.verification),
                icon: verificationIcon(incident.verification),
              ),
              StatusPill(
                label: context.tr(incident.status.labelKey),
                color: incident.status == IncidentStatus.resolved
                    ? AppColors.green
                    : AppColors.cyan,
                icon: Icons.adjust_rounded,
              ),
              if (incident.peopleAffected > 0)
                StatusPill(
                  label:
                      '${incident.peopleAffected} ${context.tr('people_affected')}',
                  color: AppColors.blue,
                  icon: Icons.people_alt_rounded,
                ),
            ],
          ),
          if (incident.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              incident.description.trim(),
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.text,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              StatChip(
                icon: Icons.access_time_rounded,
                label: relativeTime(context, incident.createdAt),
              ),
              const SizedBox(width: 12),
              StatChip(
                icon: Icons.route_rounded,
                label: context.tr('relay_count', {'count': incident.relayCount}),
              ),
              const SizedBox(width: 12),
              StatChip(
                icon: Icons.mark_email_read_rounded,
                label:
                    context.tr('pending_receipts', {'count': incident.receiptCount}),
                color: incident.receiptCount > 0
                    ? AppColors.green
                    : AppColors.textDim,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final location = incident.location;
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      accent: AppColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('location').toUpperCase(),
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: AppColors.cyan,
                ),
              ),
              const Spacer(),
              StatusPill(
                label: location.isLive
                    ? context.tr('location_live')
                    : context.tr('last_known'),
                color: location.isLive ? AppColors.green : AppColors.amber,
                icon: locationSourceIcon(location.source.wire),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 9),
          OfflineMapView(
            center: LatLng(location.latitude, location.longitude),
            zoom: 15.5,
            height: 170,
            showControls: false,
            markers: [
              MapMarkerData(
                latitude: location.latitude,
                longitude: location.longitude,
                kind: incident.kind == IncidentKind.sos
                    ? MapMarkerKind.sos
                    : MapMarkerKind.hazard,
                label: context.tr(incident.category.labelKey),
                color: categoryColor(incident.category),
                isDemo: incident.isDemo,
                pulse: incident.severity == Severity.critical,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: LabeledValue(
                  label: 'Coordinates',
                  value:
                      '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                  monospace: true,
                ),
              ),
              LabeledValue(
                label: context.tr('accuracy'),
                value: '±${location.accuracyMeters.round()} m',
              ),
              const SizedBox(width: 12),
              LabeledValue(
                label: context.tr('source'),
                value: context.tr('source_${location.source.wire}'),
              ),
            ],
          ),
          if (!location.isLive) ...[
            const SizedBox(height: 7),
            Text(
              '${context.tr('last_known')}: ${dateTimeLabel(location.capturedAt)} · NOT a live location.',
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.amber,
              ),
            ),
          ],
          if (location.description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              location.description,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.incident, required this.priority});
  final Incident incident;
  final PriorityAssessment priority;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority.band);
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sort_rounded, size: 16, color: AppColors.amber),
              const SizedBox(width: 6),
              Text(
                context.tr('priority').toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.amber,
                ),
              ),
              const Spacer(),
              StatusPill(
                label: context.tr(priority.band.labelKey),
                color: color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priority.score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: color,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3, left: 4),
                child: Text(
                  '/ 100',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textDim,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${priority.waitingMinutes} min waiting',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final factor in priority.factors)
            _FactorBar(
              label: factor.label,
              detail: factor.detail,
              points: factor.points,
              maxPoints: factor.maxPoints,
              color: color,
            ),
          const SizedBox(height: 6),
          Text(
            priority.explanation,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.4,
              color: AppColors.textDim,
            ),
          ),
          if (priority.responderDistanceKm == null) ...[
            const SizedBox(height: 5),
            const Text(
              'Responder proximity factor unavailable — 0/5 points applied, not guessed.',
              style: TextStyle(fontSize: 9, color: AppColors.amber),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactorBar extends StatelessWidget {
  const _FactorBar({
    required this.label,
    required this.detail,
    required this.points,
    required this.maxPoints,
    required this.color,
  });

  final String label;
  final String detail;
  final double points;
  final double maxPoints;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                '${points.toStringAsFixed(1)}/${maxPoints.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 8.5,
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: maxPoints <= 0 ? 0 : (points / maxPoints).clamp(0, 1),
              minHeight: 3.5,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(fontSize: 8, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.incident,
    required this.evidence,
    required this.isResponder,
    required this.onOpenResponder,
    required this.onVerify,
    required this.onDispute,
    required this.onCorroborate,
    required this.isOwn,
  });

  final Incident incident;
  final VerificationResult? evidence;
  final bool isResponder;
  final VoidCallback onOpenResponder;
  final VoidCallback onVerify;
  final VoidCallback onDispute;
  final VoidCallback onCorroborate;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final color = verificationColor(incident.verification);
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(verificationIcon(incident.verification),
                  size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                context.tr('verification').toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: color,
                ),
              ),
              const Spacer(),
              StatusPill(
                label: context.tr(incident.verification.labelKey),
                color: color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            evidence?.explanation ??
                'Independent reports and local responder votes can change this state.',
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              StatChip(
                icon: Icons.groups_rounded,
                label: context.tr('independent_reporters', {
                  'count': incident.independentReporters,
                }),
                color: AppColors.cyan,
              ),
              const SizedBox(width: 12),
              if (evidence != null)
                StatChip(
                  icon: Icons.public_rounded,
                  label:
                      '${evidence!.corroboratingIncidentIds.length} corroborating reports',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              if (!isOwn)
                OutlineAction(
                  icon: Icons.add_task_rounded,
                  label: context.tr('corroborate'),
                  onPressed: onCorroborate,
                  expand: false,
                ),
              if (isResponder) ...[
                OutlineAction(
                  icon: Icons.verified_rounded,
                  label: context.tr('mark_verified'),
                  color: AppColors.green,
                  onPressed: onVerify,
                  expand: false,
                ),
                OutlineAction(
                  icon: Icons.gavel_rounded,
                  label: context.tr('mark_disputed'),
                  color: AppColors.red,
                  onPressed: onDispute,
                  expand: false,
                ),
              ] else
                TextButton(
                  onPressed: onOpenResponder,
                  child: Text(context.tr('responder_login')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskZoneCard extends StatelessWidget {
  const _RiskZoneCard({required this.zone});
  final RiskZone zone;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(zone.level);
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  size: 16, color: AppColors.blue),
              const SizedBox(width: 6),
              Text(
                context.tr('estimated_warning').split('.').first.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.blue,
                ),
              ),
              const Spacer(),
              StatusPill(
                label: '${zone.score.toStringAsFixed(0)}/100 · ${context.tr(zone.level.labelKey)}',
                color: color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${context.tr('observed_reports', {'count': zone.observedCount})} · ${context.tr('estimated')} risk within ~${zone.radiusMeters.round()} m. Not a sensor reading.',
            style: const TextStyle(
              fontSize: 10,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelayCard extends StatelessWidget {
  const _RelayCard({required this.incident, required this.message});
  final Incident incident;
  final MessageRecord? message;

  @override
  Widget build(BuildContext context) {
    final status = message?.status;
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 16, color: AppColors.cyan),
              const SizedBox(width: 6),
              Text(
                'MESH DELIVERY',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.cyan,
                ),
              ),
              const Spacer(),
              StatusPill(
                label: status == null
                    ? context.tr('stored_locally')
                    : status == MeshDeliveryStatus.acknowledged
                        ? context.tr('acknowledged')
                        : status == MeshDeliveryStatus.transmitted
                            ? context.tr('transmitted')
                            : context.tr('queued'),
                color: status == MeshDeliveryStatus.acknowledged
                    ? AppColors.green
                    : status == MeshDeliveryStatus.transmitted
                        ? AppColors.cyan
                        : AppColors.amber,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LabeledValue(
                  label: context.tr('received'),
                  value: message == null
                      ? '—'
                      : dateTimeLabel(message!.receivedAt),
                ),
              ),
              LabeledValue(
                label: context.tr('hop', {
                  'current': message?.hopCount ?? 0,
                  'max': message?.maxHops ?? 6
                }),
                value: '${incident.relayCount} relays',
              ),
              const SizedBox(width: 12),
              LabeledValue(
                label: context.tr('receipt_confirmed', {
                  'count': incident.receiptCount
                }),
                value: '${incident.receiptCount}',
                valueColor: incident.receiptCount > 0
                    ? AppColors.green
                    : AppColors.textMuted,
              ),
            ],
          ),
          if (message?.payloadJson != null) ...[
            const SizedBox(height: 7),
            Text(
              'Payload is stored locally after authenticated decryption. Forwarding is recorded in the black box.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({required this.state, required this.incident});
  final AppState state;
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    if (!state.isResponder) {
      return GlowSurface(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.textDim),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('responder_required'),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ResponderDashboardScreen(),
                ),
              ),
              child: Text(context.tr('responder_mode')),
            ),
          ],
        ),
      );
    }
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      accent: AppColors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESPONDER ACTIONS',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              for (final status in [
                IncidentStatus.acknowledged,
                IncidentStatus.responding,
                IncidentStatus.resolved,
              ])
                OutlineAction(
                  icon: status == IncidentStatus.resolved
                      ? Icons.task_alt_rounded
                      : Icons.update_rounded,
                  label: context.tr('mark_${status == IncidentStatus.acknowledged ? 'ack' : status == IncidentStatus.responding ? 'responding' : 'resolved'}'),
                  color: status == IncidentStatus.resolved
                      ? AppColors.green
                      : AppColors.cyan,
                  expand: false,
                  onPressed: incident.status == status
                      ? null
                      : () => state.updateIncidentStatus(incident, status),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.state, required this.incident});
  final AppState state;
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final events = state.events
        .where((event) =>
            event.messageId == incident.id ||
            event.detail.contains(incident.id))
        .take(10)
        .toList(growable: false);
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  size: 16, color: AppColors.cyan),
              const SizedBox(width: 6),
              Text(
                context.tr('incident_timeline').toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (events.isEmpty)
            Text(
              context.tr('no_events'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (var i = 0; i < events.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: i == 0
                                ? AppColors.cyan
                                : AppColors.borderStrong,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i != events.length - 1)
                          Container(
                            width: 1,
                            height: 24,
                            color: AppColors.border,
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            events[i].type.wire
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            events[i].detail,
                            style: const TextStyle(
                              fontSize: 9.5,
                              height: 1.4,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      relativeTime(context, events[i].createdAt),
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
