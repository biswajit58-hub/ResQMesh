import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/status_styles.dart';
import '../../core/utilities/formatters.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../models/priority_assessment.dart';
import '../../models/risk_zone.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/common.dart';
import '../incident/incident_detail_screen.dart';

class IntelligenceScreen extends StatelessWidget {
  const IntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final zones = state.riskZones;
    final priority = [...state.activeIncidents]..sort((a, b) {
        final aScore = state.assessmentFor(a.id)?.score ?? 0;
        final bScore = state.assessmentFor(b.id)?.score ?? 0;
        return bScore.compareTo(aScore);
      });
    return PageScaffold(
      title: context.tr('intel_title'),
      subtitle: context.tr('intel_subtitle'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isDemo) ...[
              const DemoBanner(compact: true),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: context.tr('resident_reports'),
                    value: '${state.activeHazards.length}',
                    icon: Icons.report_rounded,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: MetricTile(
                    label: context.tr('risk_zones'),
                    value: '${zones.length}',
                    icon: Icons.insights_rounded,
                    color: AppColors.red,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: MetricTile(
                    label: context.tr('priority_queue'),
                    value: '${priority.length}',
                    icon: Icons.sort_rounded,
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InfoBanner(
              title: context.tr('estimated_warning'),
              message:
                  'Every score below is computed by a transparent rule engine from locally stored reports. Observed counts are shown separately from estimated risk. No flood sensor, weather feed or prediction model is present.',
              color: AppColors.amber,
              icon: Icons.psychology_alt_rounded,
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: context.tr('risk_zones'),
              subtitle: context.tr('transparent_scoring'),
            ),
            if (zones.isEmpty)
              GlowSurface(
                child: EmptyState(
                  icon: Icons.radar_rounded,
                  title: context.tr('no_zones'),
                  body: context.tr('observed_reports', {'count': 0}),
                  compact: true,
                ),
              )
            else
              ...zones.map(
                (zone) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _RiskZoneCard(zone: zone, state: state),
                ),
              ),
            const SizedBox(height: 16),
            SectionHeader(
              title: context.tr('priority_queue'),
              subtitle: context.tr('human_oversight'),
            ),
            if (priority.isEmpty)
              GlowSurface(
                child: EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: context.tr('no_queue'),
                  compact: true,
                ),
              )
            else
              ...priority.map(
                (incident) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PriorityRow(
                    incident: incident,
                    assessment: state.assessmentFor(incident.id),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            IncidentDetailScreen(incident: incident),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const InfoBanner(
              icon: Icons.gavel_rounded,
              color: AppColors.red,
              title: 'DECISION SUPPORT ONLY',
              message:
                  'Priority ordering never dispatches resources automatically. Human responders must verify the situation, accessibility and their own safety.',
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskZoneCard extends StatelessWidget {
  const _RiskZoneCard({required this.zone, required this.state});
  final RiskZone zone;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(zone.level);
    final incidents = state.incidents
        .where((e) => zone.incidentIds.contains(e.id))
        .toList(growable: false);
    return GlowSurface(
      padding: EdgeInsets.zero,
      accent: color,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 10, 0),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          iconColor: color,
          collapsedIconColor: AppColors.textDim,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(categoryIcon(zone.category), color: color, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.tr(zone.category.labelKey),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (zone.isDemo) const DemoBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${context.tr('observed_reports', {'count': zone.observedCount})} · ${zone.independentReporters} independent',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    zone.score.toStringAsFixed(0),
                    style: TextStyle(
                      color: color,
                      fontSize: 21,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.tr(zone.level.labelKey),
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: zone.score / 100,
                minHeight: 5,
                backgroundColor: AppColors.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusPill(
                  label: zone.trend.wire.toUpperCase(),
                  color: zone.trend == RiskTrend.increasing
                      ? AppColors.red
                      : zone.trend == RiskTrend.decreasing
                          ? AppColors.green
                          : AppColors.cyan,
                  icon: zone.trend == RiskTrend.increasing
                      ? Icons.trending_up_rounded
                      : zone.trend == RiskTrend.decreasing
                          ? Icons.trending_down_rounded
                          : Icons.trending_flat_rounded,
                  dense: true,
                ),
                const SizedBox(width: 7),
                StatusPill(
                  label: '${zone.radiusMeters.round()} m radius',
                  color: AppColors.textMuted,
                  dense: true,
                ),
                const Spacer(),
                Text(
                  context.tr('estimated').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            for (final factor in zone.factors)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        factor.contribution >= 0
                            ? '+${factor.contribution.toStringAsFixed(1)}'
                            : factor.contribution.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          color: factor.contribution < 0
                              ? AppColors.red
                              : AppColors.green,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            factor.label,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            factor.detail,
                            style: const TextStyle(
                              fontSize: 8.5,
                              height: 1.35,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            if (incidents.isNotEmpty)
              ...incidents.take(3).map(
                    (incident) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                IncidentDetailScreen(incident: incident),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(categoryIcon(incident.category),
                                size: 12, color: categoryColor(incident.category)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                incident.description.isEmpty
                                    ? incident.id
                                    : incident.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            Text(
                              relativeTime(context, incident.createdAt),
                              style: const TextStyle(
                                fontSize: 8,
                                color: AppColors.textDim,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                size: 13, color: AppColors.textDim),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({
    required this.incident,
    required this.assessment,
    required this.onTap,
  });

  final Incident incident;
  final PriorityAssessment? assessment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final band = assessment?.band ?? PriorityBand.routine;
    final color = priorityColor(band);
    return GlowSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      accent: color,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                assessment?.score.toStringAsFixed(0) ?? '—',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(incident.category.labelKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (incident.isDemo) const DemoBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${incident.peopleAffected} people · ${relativeTime(context, incident.createdAt)} · ${context.tr(incident.verification.labelKey)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          StatusPill(
            label: context.tr(band.labelKey),
            color: color,
            dense: true,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.textDim),
        ],
      ),
    );
  }
}
