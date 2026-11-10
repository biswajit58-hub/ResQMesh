import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/status_styles.dart';
import '../../models/enums.dart';
import '../../services/app_state.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import '../../widgets/offline_map_view.dart';
import '../incident/incident_detail_screen.dart';
import '../shelters/shelter_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _hazards = true;
  bool _sos = true;
  bool _shelters = true;
  bool _nodes = true;
  bool _zones = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final center = state.currentLocation;
    final latLng = center == null
        ? const LatLng(20.2961, 85.8245)
        : LatLng(center.latitude, center.longitude);
    final markers = <MapMarkerData>[];
    if (_sos) {
      for (final incident in state.activeSos) {
        markers.add(MapMarkerData(
          latitude: incident.location.latitude,
          longitude: incident.location.longitude,
          kind: MapMarkerKind.sos,
          label: 'SOS · ${context.tr(incident.category.labelKey)}',
          color: AppColors.red,
          pulse: incident.severity == Severity.critical,
          isDemo: incident.isDemo,
          referenceId: incident.id,
        ));
      }
    }
    if (_hazards) {
      for (final incident in state.activeHazards) {
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
    if (_shelters) {
      for (final shelter in state.shelters) {
        markers.add(MapMarkerData(
          latitude: shelter.latitude,
          longitude: shelter.longitude,
          kind: MapMarkerKind.shelter,
          label: shelter.name,
          color: shelterColor(shelter.status),
          isDemo: shelter.isDemo,
          referenceId: shelter.id,
        ));
      }
    }
    if (_nodes && center != null && !state.isDemo) {
      // Real peer locations are not collected by default, so peers are listed
      // in the device screen rather than placed at invented coordinates.
    }
    if (_nodes && state.isDemo) {
      final demoPeers = state.peers.take(4).toList();
      for (var i = 0; i < demoPeers.length; i++) {
        markers.add(MapMarkerData(
          latitude: center!.latitude + 0.006 * (i + 1) * (i.isEven ? 1 : -1),
          longitude: center.longitude +
              0.006 * (i + 1) * (i % 4 < 2 ? 1 : -1) * 0.8,
          kind: MapMarkerKind.node,
          label: demoPeers[i].displayName,
          color: AppColors.cyan,
          isDemo: true,
        ));
      }
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
              child: AppHeader(
                title: context.tr('map_title'),
                subtitle:
                    '${state.activeIncidents.length} incidents · ${state.shelters.length} shelters',
                showBack: true,
                trailing: NetworkPill(
                  online: state.online,
                  meshConnected: state.connectedPeerCount,
                ),
              ),
            ),
            if (state.isDemo)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: DemoBanner(compact: true),
              ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _MapChip(
                    label: context.tr('sos_layer'),
                    color: AppColors.red,
                    selected: _sos,
                    onTap: () => setState(() => _sos = !_sos),
                  ),
                  _MapChip(
                    label: context.tr('hazards_layer'),
                    color: AppColors.amber,
                    selected: _hazards,
                    onTap: () => setState(() => _hazards = !_hazards),
                  ),
                  _MapChip(
                    label: context.tr('shelters_layer'),
                    color: AppColors.green,
                    selected: _shelters,
                    onTap: () => setState(() => _shelters = !_shelters),
                  ),
                  _MapChip(
                    label: context.tr('nodes_layer'),
                    color: AppColors.cyan,
                    selected: _nodes,
                    onTap: () => setState(() => _nodes = !_nodes),
                  ),
                  _MapChip(
                    label: context.tr('risk_zones'),
                    color: AppColors.blue,
                    selected: _zones,
                    onTap: () => setState(() => _zones = !_zones),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => OfflineMapView(
                  center: latLng,
                  zoom: 13.2,
                  height: constraints.maxHeight,
                  markers: markers,
                  showLabels: false,
                  circles: _zones
                      ? [
                          for (final zone in state.riskZones.take(8))
                            MapCircleData(
                              latitude: zone.center.latitude,
                              longitude: zone.center.longitude,
                              radiusMeters: zone.radiusMeters,
                              color: riskColor(zone.level),
                            ),
                        ]
                      : const [],
                  onMarkerTap: (marker) {
                    if (marker.referenceId == null) return;
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
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShelterScreen(),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _LegendDot(
                            color: AppColors.red,
                            label: context.tr('sos_label')),
                        _LegendDot(
                            color: AppColors.amber,
                            label: context.tr('hazard_label')),
                        _LegendDot(
                            color: AppColors.green,
                            label: context.tr('shelter_label')),
                        _LegendDot(
                            color: AppColors.blue,
                            label: context.tr('estimated')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('map_data_warning'),
                            style: const TextStyle(
                              fontSize: 8.5,
                              height: 1.35,
                              color: AppColors.textDim,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (center != null)
                          StatusPill(
                            label: center.isLive
                                ? context.tr('gps_live')
                                : context.tr('gps_last_known'),
                            color: center.isLive
                                ? AppColors.green
                                : AppColors.amber,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.13)
                : AppColors.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.45) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected ? color : AppColors.textDim,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 8.5, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}
