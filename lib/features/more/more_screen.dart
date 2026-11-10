import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../services/app_state.dart';
import '../../widgets/app_header.dart';
import '../../widgets/background.dart';
import '../../widgets/common.dart';
import '../alerts/alerts_screen.dart';
import '../demo/demo_lab_screen.dart';
import '../digital_twin/digital_twin_screen.dart';
import '../disaster_intelligence/intelligence_screen.dart';
import '../event_history/event_history_screen.dart';
import '../hazard_mapping/hazard_report_screen.dart';
import '../hazard_mapping/map_screen.dart';
import '../incident/incident_detail_screen.dart';
import '../mesh_network/inbox_screen.dart';
import '../mesh_network/nearby_devices_screen.dart';
import '../responder/responder_dashboard_screen.dart';
import '../settings/settings_screen.dart';
import '../shelters/shelter_screen.dart';
import '../sos/sos_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppHeader(
                  title: context.tr('more'),
                  subtitle: context.tr('app_tagline'),
                  trailing: NetworkPill(
                    online: state.online,
                    meshConnected: state.connectedPeerCount,
                  ),
                ),
                const SizedBox(height: 14),
                if (state.isDemo) ...[
                  const DemoBanner(),
                  const SizedBox(height: 12),
                ],
                GlowSurface(
                  padding: const EdgeInsets.all(15),
                  accent: state.isDemo ? AppColors.amber : AppColors.cyan,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: state.isDemo
                                ? [AppColors.amber, AppColors.red]
                                : [AppColors.cyan, AppColors.blue],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            state.deviceName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.background,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    state.deviceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (state.isDemo) ...[
                                  const SizedBox(width: 6),
                                  const DemoBadge(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              state.deviceId,
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontFamily: 'monospace',
                                color: AppColors.textDim,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  state.meshRunning
                                      ? Icons.hub_rounded
                                      : Icons.wifi_off_rounded,
                                  size: 11,
                                  color: state.meshRunning
                                      ? AppColors.green
                                      : AppColors.textDim,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  state.isDemo
                                      ? 'DEMO · NO RADIOS'
                                      : state.meshRunning
                                          ? context.tr('mesh_active')
                                          : context.tr('mesh_inactive'),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: state.meshRunning
                                        ? AppColors.green
                                        : AppColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: context.tr('home_situation'),
                  subtitle: '${state.activeIncidents.length} active · ${state.peers.length} nodes',
                ),
                _FeatureGrid(
                  items: [
                    _Feature(
                      icon: Icons.sos_rounded,
                      label: context.tr('sos_title'),
                      color: AppColors.red,
                      onTap: () => _push(context, const SosScreen()),
                    ),
                    _Feature(
                      icon: Icons.report_problem_rounded,
                      label: context.tr('report_hazard'),
                      color: AppColors.amber,
                      onTap: () => _push(context, const HazardReportScreen()),
                    ),
                    _Feature(
                      icon: Icons.home_work_rounded,
                      label: context.tr('shelters_title'),
                      color: AppColors.green,
                      onTap: () => _push(context, const ShelterScreen()),
                    ),
                    _Feature(
                      icon: Icons.map_rounded,
                      label: context.tr('map_title'),
                      color: AppColors.cyan,
                      onTap: () => _push(context, const MapScreen()),
                    ),
                    _Feature(
                      icon: Icons.hub_rounded,
                      label: context.tr('mesh_title'),
                      color: AppColors.cyan,
                      onTap: () => _push(context, const NearbyDevicesScreen()),
                    ),
                    _Feature(
                      icon: Icons.mail_rounded,
                      label: context.tr('message_inbox'),
                      color: AppColors.blue,
                      badge: '${state.messages.length}',
                      onTap: () => _push(context, const InboxScreen()),
                    ),
                    _Feature(
                      icon: Icons.badge_rounded,
                      label: context.tr('responder_title'),
                      color: AppColors.green,
                      onTap: () =>
                          _push(context, const ResponderDashboardScreen()),
                    ),
                    _Feature(
                      icon: Icons.insights_rounded,
                      label: context.tr('intel_title'),
                      color: AppColors.blue,
                      onTap: () => _push(context, const IntelligenceScreen()),
                    ),
                    _Feature(
                      icon: Icons.hub_rounded,
                      label: context.tr('digital_twin'),
                      color: AppColors.purple,
                      onTap: () => _push(context, const DigitalTwinScreen()),
                    ),
                    _Feature(
                      icon: Icons.inventory_2_rounded,
                      label: context.tr('history_title'),
                      color: AppColors.amber,
                      onTap: () => _push(context, const EventHistoryScreen()),
                    ),
                    _Feature(
                      icon: Icons.science_rounded,
                      label: context.tr('demo_lab'),
                      color: AppColors.amber,
                      onTap: () => _push(context, const DemoLabScreen()),
                    ),
                    _Feature(
                      icon: Icons.tune_rounded,
                      label: context.tr('settings'),
                      color: AppColors.textMuted,
                      onTap: () => _push(context, const SettingsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: context.tr('recent_incidents'),
                  actionLabel: context.tr('view_all'),
                  onAction: () => _push(context, const AlertsScreen()),
                ),
                if (state.activeIncidents.isEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: GlowSurface(
                      child: EmptyState(
                        icon: Icons.radar_rounded,
                        title: context.tr('no_incidents'),
                        compact: true,
                      ),
                    ),
                  )
                else
                  ...state.activeIncidents.take(2).map(
                        (incident) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlowSurface(
                            onTap: () => _push(
                              context,
                              IncidentDetailScreen(incident: incident),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.bolt_rounded,
                                    size: 16, color: AppColors.amber),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    incident.description.isEmpty
                                        ? incident.category.wire
                                        : incident.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5),
                                  ),
                                ),
                                Text(
                                  relativeTime(context, incident.createdAt),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: AppColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 16),
                GlowSurface(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'ResQMesh is a hackathon prototype. It does not guarantee message delivery or safety. It is not an official emergency service. In a life-threatening emergency, contact local authorities when any network is available.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.items});
  final List<_Feature> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _FeatureTile(feature: item);
      },
    );
  }
}

class _Feature {
  const _Feature({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: feature.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: feature.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(feature.icon, color: feature.color, size: 18),
                ),
                if (feature.badge != null)
                  Positioned(
                    right: -5,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: feature.color,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        feature.badge!,
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: AppColors.background,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              feature.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
