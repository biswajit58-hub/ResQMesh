import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../models/enums.dart';
import '../../models/message_record.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/common.dart';

import '../incident/incident_detail_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    var messages = state.messages;
    if (_filter == 1) {
      messages = messages
          .where((m) =>
              m.type == MeshMessageType.sos || m.type == MeshMessageType.hazard)
          .toList();
    } else if (_filter == 2) {
      messages =
          messages.where((m) => m.type == MeshMessageType.ack).toList();
    } else if (_filter == 3) {
      messages = messages
          .where((m) => m.type == MeshMessageType.presence ||
              m.type == MeshMessageType.text)
          .toList();
    }
    return PageScaffold(
      title: context.tr('message_inbox'),
      subtitle: context.tr('delivery_disclaimer'),
      child: Column(
        children: [
          if (state.isDemo)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DemoBanner(compact: true),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _MessageChip(
                  label: context.tr('all'),
                  selected: _filter == 0,
                  count: state.messages.length,
                  onTap: () => setState(() => _filter = 0),
                ),
                _MessageChip(
                  label: context.tr('filter_incidents'),
                  selected: _filter == 1,
                  count: state.messages
                      .where((m) =>
                          m.type == MeshMessageType.sos ||
                          m.type == MeshMessageType.hazard)
                      .length,
                  onTap: () => setState(() => _filter = 1),
                ),
                _MessageChip(
                  label: 'ACK',
                  selected: _filter == 2,
                  count: state.messages
                      .where((m) => m.type == MeshMessageType.ack)
                      .length,
                  onTap: () => setState(() => _filter = 2),
                ),
                _MessageChip(
                  label: context.tr('filter_mesh'),
                  selected: _filter == 3,
                  count: state.messages
                      .where((m) => m.type == MeshMessageType.presence)
                      .length,
                  onTap: () => setState(() => _filter = 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Expanded(
            child: messages.isEmpty
                ? EmptyState(
                    icon: Icons.mail_outline_rounded,
                    title: context.tr('inbox_empty'),
                    body: context.tr('inbox_empty_hint'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _MessageTile(message: messages[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageChip extends StatelessWidget {
  const _MessageChip({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.cyanSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? AppColors.cyan : AppColors.border,
            ),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.cyan : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});
  final MessageRecord message;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final incident = state.incidents
        .where((i) => i.id == message.id)
        .firstOrNull;
    final color = message.type == MeshMessageType.ack
        ? AppColors.green
        : message.type == MeshMessageType.sos
            ? AppColors.red
            : message.type == MeshMessageType.hazard
                ? AppColors.amber
                : AppColors.cyan;
    final icon = switch (message.type) {
      MeshMessageType.sos => Icons.sos_rounded,
      MeshMessageType.hazard => Icons.warning_amber_rounded,
      MeshMessageType.ack => Icons.mark_email_read_rounded,
      MeshMessageType.presence => Icons.sensors_rounded,
      MeshMessageType.shelterUpdate => Icons.home_rounded,
      MeshMessageType.statusUpdate => Icons.update_rounded,
      MeshMessageType.text => Icons.chat_bubble_outline_rounded,
    };
    return GlowSurface(
      onTap: incident == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IncidentDetailScreen(incident: incident),
                ),
              ),
      accent: color,
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 18),
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
                        message.type == MeshMessageType.ack
                            ? 'RECEIPT ACKNOWLEDGEMENT'
                            : message.type.wire.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: color,
                        ),
                      ),
                    ),
                    if (message.isDemo) const DemoBadge(),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message.originName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      shortId(message.id),
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontFamily: 'monospace',
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('hop', {
                        'current': message.hopCount,
                        'max': message.maxHops,
                      }),
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'P${message.priority}',
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: AppColors.textDim,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      relativeTime(context, message.receivedAt),
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              StatusPill(
                label: _statusLabel(context, message.status),
                color: message.status == MeshDeliveryStatus.acknowledged
                    ? AppColors.green
                    : message.status == MeshDeliveryStatus.transmitted
                        ? AppColors.cyan
                        : AppColors.amber,
                dense: true,
              ),
              const SizedBox(height: 4),
              if (incident != null)
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.textDim),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(BuildContext context, MeshDeliveryStatus status) {
    return switch (status) {
      MeshDeliveryStatus.queued => context.tr('queued'),
      MeshDeliveryStatus.transmitted => context.tr('transmitted'),
      MeshDeliveryStatus.acknowledged => context.tr('acknowledged'),
      MeshDeliveryStatus.failed => 'FAILED',
      MeshDeliveryStatus.expired => context.tr('verification_expired'),
    };
  }
}
