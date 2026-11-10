import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/status_styles.dart';
import '../core/utilities/formatters.dart';
import '../models/enums.dart';
import '../models/incident.dart';
import '../models/priority_assessment.dart';
import 'common.dart';

class IncidentCard extends StatelessWidget {
  const IncidentCard({
    super.key,
    required this.incident,
    this.priority,
    this.onTap,
    this.compact = false,
  });

  final Incident incident;
  final PriorityAssessment? priority;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final categoryColor = statusCategoryColor(incident.category);
    return GlowSurface(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 13 : 15),
      accent: incident.kind == IncidentKind.sos ? AppColors.red : categoryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 36 : 42,
                height: compact ? 36 : 42,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: categoryColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  statusCategoryIcon(incident.category),
                  color: categoryColor,
                  size: compact ? 18 : 21,
                ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 13.5 : 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (incident.isDemo) const DemoBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        StatusPill(
                          label: context.tr(incident.severity.labelKey),
                          color: statusSeverityColor(incident.severity),
                          dense: true,
                        ),
                        const SizedBox(width: 5),
                        StatusPill(
                          label: context.tr(incident.verification.labelKey),
                          color: statusVerificationColor(incident.verification),
                          icon: statusVerificationIcon(incident.verification),
                          dense: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (priority != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusPriorityColor(priority!.band)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: statusPriorityColor(priority!.band)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        priority!.score.toStringAsFixed(0),
                        style: TextStyle(
                          color: statusPriorityColor(priority!.band),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('priority'),
                        style: const TextStyle(
                          color: AppColors.textDim,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (incident.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              incident.description.trim(),
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 12, color: AppColors.textDim),
              const SizedBox(width: 4),
              Text(
                relativeTime(context, incident.createdAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textDim,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              if (incident.peopleAffected > 0) ...[
                const Icon(Icons.people_alt_rounded,
                    size: 12, color: AppColors.textDim),
                const SizedBox(width: 4),
                Text(
                  '${incident.peopleAffected}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textDim,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (incident.receiptCount > 0) ...[
                const Icon(Icons.mark_email_read_rounded,
                    size: 12, color: AppColors.green),
                const SizedBox(width: 4),
                Text(
                  '${incident.receiptCount}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              if (incident.kind == IncidentKind.sos)
                const StatusPill(
                  label: 'SOS',
                  color: AppColors.red,
                  dense: true,
                  filled: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Color statusCategoryColor(EmergencyCategory category) => categoryColor(category);
IconData statusCategoryIcon(EmergencyCategory category) => categoryIcon(category);
Color statusSeverityColor(Severity severity) => severityColor(severity);
Color statusVerificationColor(VerificationState state) =>
    verificationColor(state);
IconData statusVerificationIcon(VerificationState state) =>
    verificationIcon(state);
Color statusPriorityColor(PriorityBand band) => priorityColor(band);
