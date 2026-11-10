import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/enums.dart';
import '../../services/app_state.dart';
import '../../widgets/app_header.dart';
import '../../widgets/background.dart';
import '../../widgets/common.dart';
import '../../widgets/incident_card.dart';
import '../incident/incident_detail_screen.dart';
import '../mesh_network/inbox_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    var incidents = state.activeIncidents;
    if (_filter == 1) {
      incidents = incidents.where((e) => e.kind == IncidentKind.sos).toList();
    } else if (_filter == 2) {
      incidents = incidents.where((e) => e.kind == IncidentKind.hazard).toList();
    } else if (_filter == 3) {
      incidents = incidents
          .where((e) =>
              e.verification == VerificationState.communityCorroborated ||
              e.verification == VerificationState.responderVerified)
          .toList();
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 10, 0),
                child: AppHeader(
                  title: context.tr('alerts'),
                  subtitle: context.tr('home_situation'),
                  showBack: Navigator.of(context).canPop(),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NetworkPill(
                        online: state.online,
                        meshConnected: state.connectedPeerCount,
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const InboxScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 20),
                        tooltip: context.tr('message_inbox'),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.isDemo)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: DemoBanner(compact: true),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: context.tr('all'),
                        selected: _filter == 0,
                        count: state.activeIncidents.length,
                        onTap: () => setState(() => _filter = 0),
                      ),
                      _FilterChip(
                        label: 'SOS',
                        selected: _filter == 1,
                        count: state.activeSos.length,
                        color: AppColors.red,
                        onTap: () => setState(() => _filter = 1),
                      ),
                      _FilterChip(
                        label: context.tr('hazards_layer'),
                        selected: _filter == 2,
                        count: state.activeHazards.length,
                        color: AppColors.amber,
                        onTap: () => setState(() => _filter = 2),
                      ),
                      _FilterChip(
                        label: context.tr('verification'),
                        selected: _filter == 3,
                        count: state.activeIncidents
                            .where((e) =>
                                e.verification ==
                                    VerificationState.responderVerified ||
                                e.verification ==
                                    VerificationState.communityCorroborated)
                            .length,
                        color: AppColors.green,
                        onTap: () => setState(() => _filter = 3),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: incidents.isEmpty
                    ? EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: context.tr('no_incidents'),
                        body: context.tr('no_incidents_hint'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                        itemCount: incidents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final incident = incidents[index];
                          return IncidentCard(
                            incident: incident,
                            priority: state.assessmentFor(incident.id),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => IncidentDetailScreen(
                                  incident: incident,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
    this.color = AppColors.cyan,
  });

  final String label;
  final bool selected;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.2)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : AppColors.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
