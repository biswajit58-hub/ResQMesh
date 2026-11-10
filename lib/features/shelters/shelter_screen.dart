import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/status_styles.dart';
import '../../core/utilities/formatters.dart';
import '../../models/enums.dart';
import '../../models/shelter.dart';
import '../../services/app_state.dart';
import '../../services/evacuation_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/background.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/offline_map_view.dart';

class ShelterScreen extends StatelessWidget {
  const ShelterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final options = state.shelterOptions();
    final center = state.currentLocation;
    final isPushed = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
                child: AppHeader(
                  title: context.tr('shelters_title'),
                  subtitle:
                      '${state.availableShelters.length} ${context.tr('available')} · ${state.shelters.length} total',
                  showBack: isPushed,
                  trailing: IconButton(
                    onPressed: () async {
                      final attempt = await state.acquireLocation();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(attempt.message)),
                        );
                      }
                    },
                    icon: const Icon(Icons.my_location_rounded, size: 20),
                  ),
                ),
              ),
              if (state.isDemo)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: DemoBanner(compact: true),
                ),
              if (center != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                  child: OfflineMapView(
                    center: LatLng(center.latitude, center.longitude),
                    zoom: 13.5,
                    height: 160,
                    showControls: false,
                    markers: [
                      MapMarkerData(
                        latitude: center.latitude,
                        longitude: center.longitude,
                        kind: MapMarkerKind.user,
                        label: 'You',
                        pulse: true,
                      ),
                      for (final shelter in state.shelters)
                        MapMarkerData(
                          latitude: shelter.latitude,
                          longitude: shelter.longitude,
                          kind: MapMarkerKind.shelter,
                          label: shelter.name,
                          color: shelterColor(shelter.status),
                          isDemo: shelter.isDemo,
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: options.isEmpty
                    ? EmptyState(
                        icon: Icons.home_work_outlined,
                        title: context.tr('no_shelters'),
                        body: context.tr('no_shelters_hint'),
                        actionLabel: context.tr('demo_lab'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: options.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return const InfoBanner(
                              icon: Icons.route_rounded,
                              color: AppColors.amber,
                              message:
                                  'Routes are advisory, computed only from cached map geometry and local hazard reports. Always confirm conditions locally.',
                            );
                          }
                          final option = options[index - 1];
                          return _ShelterCard(
                            option: option,
                            isResponder: state.isResponder,
                            onRoute: () => _showRoute(context, state, option),
                            onEdit: state.isResponder
                                ? () => _editShelter(
                                      context,
                                      state,
                                      option.shelter,
                                    )
                                : null,
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

  Future<void> _showRoute(
    BuildContext context,
    AppState state,
    ShelterOption option,
  ) async {
    final result = state.evacuationRoute(preferredShelter: option.shelter);
    if (!context.mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? context.tr('route_failed'))),
      );
      return;
    }
    final route = result.route!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('evacuation_route'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  option.shelter.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                OfflineMapView(
                  center: LatLng(
                    route.origin.latitude,
                    route.origin.longitude,
                  ),
                  zoom: 13.8,
                  height: 250,
                  markers: [
                    MapMarkerData(
                      latitude: route.origin.latitude,
                      longitude: route.origin.longitude,
                      kind: MapMarkerKind.user,
                      label: 'Start',
                      pulse: true,
                    ),
                    MapMarkerData(
                      latitude: option.shelter.latitude,
                      longitude: option.shelter.longitude,
                      kind: MapMarkerKind.shelter,
                      label: option.shelter.name,
                      color: AppColors.green,
                      isDemo: option.shelter.isDemo,
                    ),
                  ],
                  route: [
                    for (final point in route.waypoints)
                      LatLng(point.latitude, point.longitude),
                  ],
                  showControls: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RouteMetric(
                        label: context.tr('distance_away', {
                          'distance': distanceLabel(route.distanceMeters)
                        }),
                        value: context.tr('route_distance', {
                          'km': (route.distanceMeters / 1000)
                              .toStringAsFixed(1)
                        }),
                      ),
                    ),
                    Expanded(
                      child: _RouteMetric(
                        label: context.tr('route_time', {
                          'minutes': route.estimatedMinutes
                        }),
                        value: context.tr('route_steps',
                            {'count': route.waypoints.length}),
                      ),
                    ),
                    Expanded(
                      child: _RouteMetric(
                        label: context.tr('data_age', {
                          'minutes': route.dataAgeMinutes
                        }),
                        value: '${route.hazardsConsidered} hazards',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InfoBanner(
                  title: context.tr('route_warning'),
                  message: route.warnings.join('\n'),
                  color: AppColors.red,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: context.tr('close'),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editShelter(
    BuildContext context,
    AppState state,
    Shelter shelter,
  ) async {
    var status = shelter.status;
    final occupancy = TextEditingController(text: '${shelter.occupancy}');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.tr('update_shelter')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(shelter.name),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final value in ShelterStatus.values)
                    ChoiceChip(
                      label: Text(context.tr(value.labelKey)),
                      selected: status == value,
                      onSelected: (_) => setState(() => status = value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: occupancy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('occupancy'),
                  helperText: '0 – ${shelter.capacity}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final value = int.tryParse(occupancy.text) ?? shelter.occupancy;
                await state.updateShelter(
                  shelter,
                  status: status,
                  occupancy: value,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    );
    occupancy.dispose();
  }
}

class _ShelterCard extends StatelessWidget {
  const _ShelterCard({
    required this.option,
    required this.isResponder,
    required this.onRoute,
    this.onEdit,
  });

  final ShelterOption option;
  final bool isResponder;
  final VoidCallback onRoute;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final shelter = option.shelter;
    final color = shelterColor(shelter.status);
    return GlowSurface(
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.home_rounded, color: color, size: 19),
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
                            shelter.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (shelter.isDemo) const DemoBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shelter.address.isEmpty
                          ? context.tr('unknown_location')
                          : shelter.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: context.tr(shelter.status.labelKey),
                color: color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${shelter.available} ${context.tr('available')}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${shelter.occupancy}/${shelter.capacity}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textDim,
                ),
              ),
              const Spacer(),
              Text(
                option.distanceMeters.isFinite
                    ? distanceLabel(option.distanceMeters)
                    : context.tr('shelter_distance_unknown'),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: shelter.occupancyRatio,
              minHeight: 5,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(Icons.update_rounded, size: 11, color: AppColors.textDim),
              const SizedBox(width: 4),
              Text(
                relativeTime(context, shelter.updatedAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.textDim,
                ),
              ),
              if (shelter.phone.isNotEmpty) ...[
                const SizedBox(width: 10),
                Icon(Icons.phone_rounded, size: 11, color: AppColors.textDim),
                const SizedBox(width: 3),
                Text(
                  shelter.phone,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AppColors.textDim,
                  ),
                ),
              ],
              const Spacer(),
              if (isResponder && onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  child: Text(
                    context.tr('update_shelter'),
                    style: const TextStyle(fontSize: 9.5),
                  ),
                ),
              TextButton.icon(
                onPressed: onRoute,
                icon: const Icon(Icons.route_rounded, size: 14),
                label: Text(
                  context.tr('route'),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.cyan,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(fontSize: 8.5, color: AppColors.textDim),
        ),
      ],
    );
  }
}
