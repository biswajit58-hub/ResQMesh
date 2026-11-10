import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/status_styles.dart';
import '../../models/enums.dart';
import '../../models/geo_fix.dart';
import '../../models/shelter.dart';
import '../../services/app_state.dart';
import '../../widgets/app_header.dart';
import '../../widgets/background.dart';
import '../../widgets/common.dart';
import '../../widgets/incident_card.dart';
import '../../widgets/sos_button.dart';
import '../alerts/alerts_screen.dart';
import '../demo/demo_lab_screen.dart';
import '../digital_twin/digital_twin_screen.dart';
import '../disaster_intelligence/intelligence_screen.dart';
import '../event_history/event_history_screen.dart';
import '../hazard_mapping/hazard_report_screen.dart';
import '../hazard_mapping/map_screen.dart';
import '../incident/incident_detail_screen.dart';
import '../mesh_network/nearby_devices_screen.dart';
import '../responder/responder_dashboard_screen.dart';
import '../settings/settings_screen.dart';
import '../shelters/shelter_screen.dart';
import '../sos/sos_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final incidents = state.activeIncidents.take(3).toList(growable: false);
    final location = state.currentLocation;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppHeader(
                  subtitle: context.tr('app_tagline'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NetworkPill(
                        online: state.online,
                        meshConnected: state.connectedPeerCount,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _push(context, const SettingsScreen()),
                        icon: const Icon(Icons.tune_rounded, size: 19),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (state.isDemo) ...[
                  const DemoBanner(),
                  const SizedBox(height: 12),
                ],
                _HeroCard(
                  location: location,
                  isDemo: state.isDemo,
                  isLive: state.locationIsLive,
                  connectedPeers: state.isDemo
                      ? state.peers.where((p) => p.connected).length
                      : state.connectedPeerCount,
                  meshRunning: state.meshRunning,
                  onSos: () => _push(context, const SosScreen()),
                  onHazard: () => _push(context, const HazardReportScreen()),
                  onShelter: () => _push(context, const ShelterScreen()),
                  onMap: () => _push(context, const MapScreen()),
                  onLocation: () async {
                    final attempt = await state.acquireLocation();
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(attempt.message)));
                    }
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: context.tr('active_sos'),
                        value: '${state.activeSos.length}',
                        icon: Icons.sos_rounded,
                        color: AppColors.red,
                        onTap: () => _push(context, const AlertsScreen()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricTile(
                        label: context.tr('critical'),
                        value: '${state.criticalCount}',
                        icon: Icons.warning_rounded,
                        color: AppColors.amber,
                        onTap: () => _push(context, const IntelligenceScreen()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricTile(
                        label: context.tr('shelters_open'),
                        value: '${state.availableShelters.length}',
                        icon: Icons.home_work_rounded,
                        color: AppColors.green,
                        onTap: () => _push(context, const ShelterScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: context.tr('recent_incidents'),
                  subtitle: context.tr('home_situation'),
                  actionLabel: context.tr('view_all'),
                  onAction: () => _push(context, const AlertsScreen()),
                ),
                if (incidents.isEmpty)
                  GlowSurface(
                    child: EmptyState(
                      icon: Icons.radar_rounded,
                      title: context.tr('no_incidents'),
                      body: context.tr('no_incidents_hint'),
                      compact: true,
                    ),
                  )
                else
                  ...incidents.map(
                    (incident) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: IncidentCard(
                        incident: incident,
                        priority: state.assessmentFor(incident.id),
                        onTap: () => _push(
                          context,
                          IncidentDetailScreen(incident: incident),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SectionHeader(
                  title: context.tr('home_mesh_card'),
                  actionLabel: context.tr('nearby_devices'),
                  onAction: () => _push(context, const NearbyDevicesScreen()),
                ),
                _MeshOverview(state: state),
                const SizedBox(height: 20),
                SectionHeader(
                  title: context.tr('nearest_shelters'),
                  actionLabel: context.tr('view_all'),
                  onAction: () => _push(context, const ShelterScreen()),
                ),
                _ShelterStrip(
                  shelters: state.shelters,
                  onTap: (shelter) => _push(context, const ShelterScreen()),
                ),
                const SizedBox(height: 20),
                _IntelligenceTeaser(
                  state: state,
                  onTap: () => _push(context, const IntelligenceScreen()),
                  onTwin: () => _push(context, const DigitalTwinScreen()),
                ),
                const SizedBox(height: 20),
                _QuickActions(
                  onResponder: () =>
                      _push(context, const ResponderDashboardScreen()),
                  onHistory: () => _push(context, const EventHistoryScreen()),
                  onSettings: () => _push(context, const SettingsScreen()),
                  onDemo: () => _push(context, const DemoLabScreen()),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'ResQMesh v1.0 · OFFLINE CORE · ${state.deviceId}',
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textDim,
                      letterSpacing: 0.3,
                    ),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.location,
    required this.isDemo,
    required this.isLive,
    required this.connectedPeers,
    required this.meshRunning,
    required this.onSos,
    required this.onHazard,
    required this.onShelter,
    required this.onMap,
    required this.onLocation,
  });

  final GeoFix? location;
  final bool isDemo;
  final bool isLive;
  final int connectedPeers;
  final bool meshRunning;
  final VoidCallback onSos;
  final VoidCallback onHazard;
  final VoidCallback onShelter;
  final VoidCallback onMap;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = location == null
        ? context.tr('unknown_location')
        : isDemo
        ? context.tr('demo_data')
        : isLive
        ? context.tr('gps_live')
        : context.tr('gps_last_known');
    final color = isLive ? AppColors.green : AppColors.amber;
    return GlowSurface(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      accent: AppColors.red,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home_ready').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('home_situation'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: sourceLabel,
                color: color,
                icon: isLive ? Icons.gps_fixed_rounded : Icons.history_rounded,
                dense: true,
                onTap: onLocation,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SosButton(onPressed: () async => onSos(), size: 158),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  connectedPeers > 0
                      ? Icons.hub_rounded
                      : Icons.wifi_off_rounded,
                  size: 12,
                  color: connectedPeers > 0
                      ? AppColors.cyan
                      : AppColors.textDim,
                ),
                const SizedBox(width: 5),
                Text(
                  isDemo
                      ? 'SIMULATED NODES · $connectedPeers'
                      : connectedPeers > 0
                      ? context.tr('peers_connected', {'count': connectedPeers})
                      : context.tr('no_peers'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: connectedPeers > 0
                        ? AppColors.cyan
                        : AppColors.textDim,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('delivery_disclaimer').split('.').first,
                  style: const TextStyle(fontSize: 8, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.report_problem_rounded,
                  label: context.tr('report_hazard'),
                  color: AppColors.amber,
                  onTap: onHazard,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: Icons.home_work_rounded,
                  label: context.tr('find_shelter'),
                  color: AppColors.green,
                  onTap: onShelter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: Icons.map_rounded,
                  label: context.tr('open_map'),
                  color: AppColors.cyan,
                  onTap: onMap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeshOverview extends StatelessWidget {
  const _MeshOverview({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final peers = state.peers.where((p) => p.connected).toList(growable: false);
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      accent: AppColors.cyan,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: AppColors.cyan,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isDemo
                          ? 'SIMULATED SCENARIO NODES'
                          : state.meshStatusMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.isDemo
                          ? 'No radios are used in demo mode.'
                          : 'Direct peer radio · ${state.peers.length} discovered',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: state.isDemo
                    ? context.tr('simulated')
                    : state.meshRunning
                    ? context.tr('mesh_active')
                    : context.tr('mesh_inactive'),
                color: state.isDemo
                    ? AppColors.amber
                    : state.meshRunning
                    ? AppColors.green
                    : AppColors.textDim,
                dense: true,
              ),
            ],
          ),
          if (peers.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 26,
              child: Stack(
                children: [
                  for (var i = 0; i < peers.length && i < 6; i++)
                    Positioned(
                      left: i * 21.0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: peers[i].isDemo
                                ? AppColors.amber
                                : AppColors.cyan,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            peers[i].displayName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: peers[i].isDemo
                                  ? AppColors.amber
                                  : AppColors.cyan,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: (peers.length.clamp(1, 6)) * 21.0 + 4,
                    top: 4,
                    child: Text(
                      '+${peers.length}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShelterStrip extends StatelessWidget {
  const _ShelterStrip({required this.shelters, required this.onTap});
  final List<Shelter> shelters;
  final void Function(Shelter) onTap;

  @override
  Widget build(BuildContext context) {
    if (shelters.isEmpty) {
      return GlowSurface(
        child: EmptyState(
          icon: Icons.home_work_outlined,
          title: context.tr('no_shelters'),
          body: context.tr('no_shelters_hint'),
          compact: true,
        ),
      );
    }
    final sorted = [...shelters]
      ..sort(
        (a, b) => (a.available > 0 ? 0 : 1).compareTo(b.available > 0 ? 0 : 1),
      );
    return SizedBox(
      height: 134,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final shelter = sorted[index];
          final color = shelterColor(shelter.status);
          return SizedBox(
            width: 220,
            child: GlowSurface(
              onTap: () => onTap(shelter),
              padding: const EdgeInsets.all(13),
              accent: color,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home_rounded, size: 15, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          shelter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (shelter.isDemo) const DemoBadge(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${shelter.available} ${context.tr('available')} · ${shelter.capacity} ${context.tr('shelter_capacity')}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: shelter.occupancyRatio,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      StatusPill(
                        label: context.tr(shelter.status.labelKey),
                        color: color,
                        dense: true,
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.textDim,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IntelligenceTeaser extends StatelessWidget {
  const _IntelligenceTeaser({
    required this.state,
    required this.onTap,
    required this.onTwin,
  });

  final AppState state;
  final VoidCallback onTap;
  final VoidCallback onTwin;

  @override
  Widget build(BuildContext context) {
    final top = state.riskZones.isEmpty ? null : state.riskZones.first;
    return GlowSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      accent: top == null ? AppColors.blue : riskColor(top.level),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: AppColors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('intelligence'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  top == null
                      ? context.tr('no_zones')
                      : '${context.tr('observed_reports', {'count': top.observedCount})} · ${top.score.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTwin,
            icon: const Icon(Icons.hub_rounded, size: 18),
            tooltip: context.tr('digital_twin'),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onResponder,
    required this.onHistory,
    required this.onSettings,
    required this.onDemo,
  });

  final VoidCallback onResponder;
  final VoidCallback onHistory;
  final VoidCallback onSettings;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SmallAction(
          icon: Icons.badge_rounded,
          label: context.tr('responder_mode'),
          onTap: onResponder,
        ),
        _SmallAction(
          icon: Icons.inventory_2_rounded,
          label: context.tr('history_title'),
          onTap: onHistory,
        ),
        _SmallAction(
          icon: Icons.science_rounded,
          label: context.tr('demo_lab'),
          onTap: onDemo,
        ),
        _SmallAction(
          icon: Icons.settings_rounded,
          label: context.tr('settings'),
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface.withValues(alpha: 0.6),
        textStyle: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
