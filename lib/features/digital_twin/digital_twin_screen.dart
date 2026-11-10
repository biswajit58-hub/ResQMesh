import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/status_styles.dart';
import '../../core/utilities/formatters.dart';
import '../../models/enums.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/common.dart';
import '../../widgets/offline_map_view.dart';
import '../incident/incident_detail_screen.dart';

class DigitalTwinScreen extends StatefulWidget {
  const DigitalTwinScreen({super.key});

  @override
  State<DigitalTwinScreen> createState() => _DigitalTwinScreenState();
}

class _DigitalTwinScreenState extends State<DigitalTwinScreen> {
  double _windowHours = 6;
  bool _showSos = true;
  bool _showHazards = true;
  bool _showShelters = true;
  bool _showZones = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(
      Duration(minutes: (_windowHours * 60).round()),
    );
    final visibleIncidents = state.incidents
        .where((incident) => incident.createdAt.toUtc().isAfter(cutoff))
        .toList(growable: false);
    final current = state.currentLocation;
    final center = current == null
        ? const LatLng(20.2961, 85.8245)
        : LatLng(current.latitude, current.longitude);
    final markers = <MapMarkerData>[];
    if (_showSos) {
      for (final incident in visibleIncidents
          .where((e) => e.kind == IncidentKind.sos)) {
        markers.add(MapMarkerData(
          latitude: incident.location.latitude,
          longitude: incident.location.longitude,
          kind: MapMarkerKind.sos,
          label: 'SOS ${context.tr(incident.category.labelKey)}',
          color: AppColors.red,
          pulse: true,
          isDemo: incident.isDemo,
          referenceId: incident.id,
        ));
      }
    }
    if (_showHazards) {
      for (final incident in visibleIncidents
          .where((e) => e.kind == IncidentKind.hazard)) {
        markers.add(MapMarkerData(
          latitude: incident.location.latitude,
          longitude: incident.location.longitude,
          kind: MapMarkerKind.hazard,
          label: context.tr(incident.category.labelKey),
          color: categoryColor(incident.category),
          isDemo: incident.isDemo,
          referenceId: incident.id,
        ));
      }
    }
    if (_showShelters) {
      for (final shelter in state.shelters) {
        markers.add(MapMarkerData(
          latitude: shelter.latitude,
          longitude: shelter.longitude,
          kind: MapMarkerKind.shelter,
          label: shelter.name,
          color: shelterColor(shelter.status),
          isDemo: shelter.isDemo,
        ));
      }
    }
    if (state.isDemo && current != null) {
      final demoPeers = state.peers.take(4).toList(growable: false);
      for (var i = 0; i < demoPeers.length; i++) {
        markers.add(MapMarkerData(
          latitude: current.latitude + 0.008 * (i.isEven ? 1 : -1),
          longitude: current.longitude + 0.007 * (i < 2 ? 1 : -1),
          kind: MapMarkerKind.node,
          label: 'DEMO NODE ${i + 1}',
          color: AppColors.cyan,
          isDemo: true,
          pulse: true,
        ));
      }
    }
    final sosCount =
        visibleIncidents.where((e) => e.kind == IncidentKind.sos).length;
    final hazardCount =
        visibleIncidents.where((e) => e.kind == IncidentKind.hazard).length;
    return PageScaffold(
      title: context.tr('twin_title'),
      subtitle: context.tr('twin_body'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          children: [
            if (state.isDemo) ...[
              const DemoBanner(compact: true),
              const SizedBox(height: 9),
            ],
            GlowSurface(
              padding: const EdgeInsets.all(12),
              accent: AppColors.blue,
              child: Column(
                children: [
                  Row(
                    children: [
                      _TwinMetric(
                        value: '$sosCount',
                        label: context.tr('sos_label'),
                        color: AppColors.red,
                      ),
                      _TwinMetric(
                        value: '$hazardCount',
                        label: context.tr('hazard_label'),
                        color: AppColors.amber,
                      ),
                      _TwinMetric(
                        value: '${state.shelters.length}',
                        label: context.tr('shelter_label'),
                        color: AppColors.green,
                      ),
                      _TwinMetric(
                        value: state.isDemo
                            ? '${state.peers.where((p) => p.connected).length}'
                            : '${state.connectedPeerCount}',
                        label: context.tr('node_label'),
                        color: AppColors.cyan,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OfflineMapView(
                    center: center,
                    zoom: 12.8,
                    height: 360,
                    markers: markers,
                    showLabels: true,
                    circles: _showZones
                        ? [
                            for (final zone in state.riskZones)
                              MapCircleData(
                                latitude: zone.center.latitude,
                                longitude: zone.center.longitude,
                                radiusMeters: zone.radiusMeters,
                                color: riskColor(zone.level),
                              ),
                          ]
                        : const [],
                    onMarkerTap: (marker) {
                      final incident = state.incidents
                          .where((e) => e.id == marker.referenceId)
                          .firstOrNull;
                      if (incident != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                IncidentDetailScreen(incident: incident),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlowSurface(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timeline_rounded,
                          size: 15, color: AppColors.cyan),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('timeline').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.cyan,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _windowHours <= 1
                            ? context.tr('last_hour')
                            : context.tr('last_six_hours'),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _windowHours,
                    min: 0.5,
                    max: 12,
                    divisions: 23,
                    label: '${_windowHours.toStringAsFixed(1)} h',
                    onChanged: (value) => setState(() => _windowHours = value),
                  ),
                  Row(
                    children: [
                      Text(
                        'now',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        '−12 h',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _LayerToggle(
                        label: context.tr('sos_layer'),
                        color: AppColors.red,
                        active: _showSos,
                        onTap: () => setState(() => _showSos = !_showSos),
                      ),
                      _LayerToggle(
                        label: context.tr('hazards_layer'),
                        color: AppColors.amber,
                        active: _showHazards,
                        onTap: () => setState(() => _showHazards = !_showHazards),
                      ),
                      _LayerToggle(
                        label: context.tr('shelters_layer'),
                        color: AppColors.green,
                        active: _showShelters,
                        onTap: () =>
                            setState(() => _showShelters = !_showShelters),
                      ),
                      _LayerToggle(
                        label: context.tr('risk_zones'),
                        color: AppColors.blue,
                        active: _showZones,
                        onTap: () => setState(() => _showZones = !_showZones),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlowSurface(
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sensors_off_rounded,
                      size: 17, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.isDemo
                          ? 'Demo node positions are synthetic and labelled. In field mode, ResQMesh does not place peers at invented coordinates: connected nodes are listed without a map position unless a location is explicitly shared.'
                          : 'Connected peer positions are not collected by default. Node count is real; no peer is drawn at an invented coordinate.',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.45,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionHeader(
              title: 'Recent deltas',
              subtitle: 'Changes inside the selected window',
            ),
            if (visibleIncidents.isEmpty)
              GlowSurface(
                child: EmptyState(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'No reports in this window',
                  compact: true,
                ),
              )
            else
              ...visibleIncidents.take(6).map(
                    (incident) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: GlowSurface(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                IncidentDetailScreen(incident: incident),
                          ),
                        ),
                        padding: const EdgeInsets.all(11),
                        child: Row(
                          children: [
                            Icon(categoryIcon(incident.category),
                                size: 15,
                                color: categoryColor(incident.category)),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                incidenceLabel(context, incident.kind, incident.category),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              relativeTime(context, incident.createdAt),
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: AppColors.textDim,
                              ),
                            ),
                            if (incident.isDemo) ...[
                              const SizedBox(width: 5),
                              const DemoBadge(),
                            ],
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

  String incidenceLabel(
    BuildContext context,
    IncidentKind kind,
    EmergencyCategory category,
  ) =>
      '${kind.wire.toUpperCase()} · ${context.tr(category.labelKey)}';
}

class _TwinMetric extends StatelessWidget {
  const _TwinMetric({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                color: color,
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  const _LayerToggle({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.1)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: active ? color : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}
