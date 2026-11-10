import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../models/audit_event.dart';
import '../../models/enums.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/common.dart';

class EventHistoryScreen extends StatefulWidget {
  const EventHistoryScreen({super.key});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  int _filter = 0;
  bool _exporting = false;

  static const _meshTypes = {
    AuditEventType.meshStarted,
    AuditEventType.meshStopped,
    AuditEventType.meshUnavailable,
    AuditEventType.peerDiscovered,
    AuditEventType.peerConnected,
    AuditEventType.peerDisconnected,
    AuditEventType.messageQueued,
    AuditEventType.messageSent,
    AuditEventType.messageReceived,
    AuditEventType.messageForwarded,
    AuditEventType.messageAcknowledged,
    AuditEventType.duplicateDropped,
    AuditEventType.invalidDropped,
    AuditEventType.rateLimited,
    AuditEventType.securityWarning,
  };

  static const _incidentTypes = {
    AuditEventType.sosCreated,
    AuditEventType.hazardCreated,
    AuditEventType.verificationChanged,
    AuditEventType.messageExpired,
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    var events = state.events;
    if (_filter == 1) {
      events = events.where((e) => _meshTypes.contains(e.type)).toList();
    } else if (_filter == 2) {
      events = events.where((e) => _incidentTypes.contains(e.type)).toList();
    } else if (_filter == 3) {
      events = events
          .where((e) =>
              !_meshTypes.contains(e.type) && !_incidentTypes.contains(e.type))
          .toList();
    }
    return PageScaffold(
      title: context.tr('history_title'),
      subtitle: context.tr('black_box_desc'),
      actions: [
        IconButton(
          onPressed: _exporting ? null : () => _export(state),
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded, size: 20),
          tooltip: context.tr('export'),
        ),
      ],
      child: Column(
        children: [
          if (state.isDemo)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DemoBanner(compact: true),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _HistoryStat(
                  label: context.tr('event_count', {'count': state.events.length}),
                  value: '${state.events.length}',
                ),
                const Spacer(),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: _HistoryFilter(
                      label: [
                        context.tr('filter_all'),
                        context.tr('filter_mesh'),
                        context.tr('filter_incidents'),
                        context.tr('filter_actions'),
                      ][i],
                      selected: _filter == i,
                      onTap: () => setState(() => _filter = i),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: context.tr('no_events'),
                    body: context.tr('black_box_desc'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) =>
                        _EventCard(event: events[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(AppState state) async {
    setState(() => _exporting = true);
    try {
      final File file = await state.exportBlackBox();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('export')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('export_created', {'path': file.path}),
                style: const TextStyle(fontSize: 11.5, height: 1.5),
              ),
              const SizedBox(height: 10),
              const InfoBanner(
                icon: Icons.info_outline_rounded,
                message:
                    'The export includes only data currently shown for this mode. Demo and field data are kept separate; synthetic records retain is_demo=true.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.path));
                Navigator.pop(context);
              },
              child: const Text('Copy path'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('close')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('error_save')} $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _HistoryFilter extends StatelessWidget {
  const _HistoryFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyanSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.cyan : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.cyan : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.cyan,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 8, color: AppColors.textDim),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(event.type);
    return GlowSurface(
      padding: const EdgeInsets.all(11),
      accent: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconFor(event.type), size: 15, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.type.wire.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: color,
                        ),
                      ),
                    ),
                    if (event.isDemo) const DemoBadge(),
                    const SizedBox(width: 5),
                    Text(
                      clockTime(event.createdAt),
                      style: const TextStyle(
                        fontSize: 8,
                        fontFamily: 'monospace',
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.detail,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.42,
                    color: AppColors.textMuted,
                  ),
                ),
                if (event.messageId != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'msg ${shortId(event.messageId!)}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontFamily: 'monospace',
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(AuditEventType type) => switch (type) {
        AuditEventType.sosCreated => Icons.sos_rounded,
        AuditEventType.hazardCreated => Icons.warning_amber_rounded,
        AuditEventType.messageSent => Icons.upload_rounded,
        AuditEventType.messageReceived => Icons.download_rounded,
        AuditEventType.messageForwarded => Icons.forward_rounded,
        AuditEventType.messageAcknowledged => Icons.mark_email_read_rounded,
        AuditEventType.duplicateDropped => Icons.content_copy_rounded,
        AuditEventType.invalidDropped => Icons.block_rounded,
        AuditEventType.peerConnected => Icons.link_rounded,
        AuditEventType.peerDisconnected => Icons.link_off_rounded,
        AuditEventType.responderLogin => Icons.login_rounded,
        AuditEventType.responderLoginFailed => Icons.no_accounts_rounded,
        AuditEventType.responderAction => Icons.badge_rounded,
        AuditEventType.verificationChanged => Icons.fact_check_rounded,
        AuditEventType.shelterUpdated => Icons.home_work_rounded,
        AuditEventType.simulationRun => Icons.science_rounded,
        AuditEventType.securityWarning => Icons.security_rounded,
        _ => Icons.bolt_rounded,
      };

  Color _colorFor(AuditEventType type) {
    if (type == AuditEventType.securityWarning ||
        type == AuditEventType.responderLoginFailed ||
        type == AuditEventType.invalidDropped) {
      return AppColors.red;
    }
    if (type == AuditEventType.messageAcknowledged ||
        type == AuditEventType.responderLogin ||
        type == AuditEventType.responderAction) {
      return AppColors.green;
    }
    if (type == AuditEventType.simulationRun ||
        type == AuditEventType.demoSeeded ||
        type == AuditEventType.demoCleared) {
      return AppColors.amber;
    }
    if (_meshTypes.contains(type)) return AppColors.cyan;
    return AppColors.blue;
  }

  static const _meshTypes = {
    AuditEventType.meshStarted,
    AuditEventType.meshStopped,
    AuditEventType.meshUnavailable,
    AuditEventType.peerDiscovered,
    AuditEventType.peerConnected,
    AuditEventType.peerDisconnected,
    AuditEventType.messageQueued,
    AuditEventType.messageSent,
    AuditEventType.messageReceived,
    AuditEventType.messageForwarded,
    AuditEventType.messageAcknowledged,
    AuditEventType.duplicateDropped,
    AuditEventType.invalidDropped,
    AuditEventType.rateLimited,
  };
}
