import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/utilities/resq_tile_provider.dart';
import '../core/utilities/tile_cache_service.dart';

enum MapMarkerKind { sos, hazard, shelter, node, user, risk }

class MapMarkerData {
  const MapMarkerData({
    required this.latitude,
    required this.longitude,
    required this.kind,
    required this.label,
    this.color,
    this.isDemo = false,
    this.pulse = false,
    this.detail,
    this.referenceId,
  });

  final double latitude;
  final double longitude;
  final MapMarkerKind kind;
  final String label;
  final Color? color;
  final bool isDemo;
  final bool pulse;
  final String? detail;
  final String? referenceId;

  LatLng get point => LatLng(latitude, longitude);
}

class MapCircleData {
  const MapCircleData({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.color,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final Color color;
}

class OfflineMapView extends StatefulWidget {
  const OfflineMapView({
    super.key,
    required this.center,
    this.zoom = 14,
    this.markers = const [],
    this.circles = const [],
    this.route = const [],
    this.height = 260,
    this.showLabels = false,
    this.showControls = true,
    this.borderRadius = 18,
    this.onMarkerTap,
  });

  final LatLng center;
  final double zoom;
  final List<MapMarkerData> markers;
  final List<MapCircleData> circles;
  final List<LatLng> route;
  final double height;
  final bool showLabels;
  final bool showControls;
  final double borderRadius;
  final void Function(MapMarkerData)? onMarkerTap;

  @override
  State<OfflineMapView> createState() => _OfflineMapViewState();
}

class _OfflineMapViewState extends State<OfflineMapView>
    with SingleTickerProviderStateMixin {
  final MapController _controller = MapController();
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: widget.center,
                initialZoom: widget.zoom,
                minZoom: 3,
                maxZoom: 18,
                backgroundColor: AppColors.backgroundAlt,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: TileCacheService.primaryTileTemplate,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.resqmesh.resqmesh',
                  tileProvider: ResqTileProvider(),
                  maxNativeZoom: 19,
                  panBuffer: 1,
                ),
                if (widget.circles.isNotEmpty)
                  CircleLayer(
                    circles: [
                      for (final circle in widget.circles)
                        CircleMarker(
                          point: LatLng(circle.latitude, circle.longitude),
                          radius: circle.radiusMeters,
                          useRadiusInMeter: true,
                          color: circle.color.withValues(alpha: 0.12),
                          borderColor: circle.color.withValues(alpha: 0.5),
                          borderStrokeWidth: 1.2,
                        ),
                    ],
                  ),
                if (widget.route.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.route,
                        color: AppColors.cyan,
                        strokeWidth: 4.5,
                        borderColor: AppColors.background,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final marker in widget.markers)
                      Marker(
                        point: marker.point,
                        width: widget.showLabels ? 150 : 54,
                        height: widget.showLabels ? 68 : 54,
                        child: _MapMarker(
                          marker: marker,
                          showLabel: widget.showLabels,
                          animation: _pulse,
                          onTap: widget.onMarkerTap,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.layers_rounded, size: 11, color: AppColors.cyan),
                    SizedBox(width: 4),
                    Text(
                      'OFFLINE-FIRST MAP',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.showControls)
              Positioned(
                right: 10,
                bottom: 34,
                child: Column(
                  children: [
                    _MapControl(
                      icon: Icons.add_rounded,
                      onTap: () => _controller.move(
                        _controller.camera.center,
                        (_controller.camera.zoom + 1).clamp(3, 18),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _MapControl(
                      icon: Icons.remove_rounded,
                      onTap: () => _controller.move(
                        _controller.camera.center,
                        (_controller.camera.zoom - 1).clamp(3, 18),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _MapControl(
                      icon: Icons.my_location_rounded,
                      onTap: () => _controller.move(widget.center, widget.zoom),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      color: AppColors.background.withValues(alpha: 0.75),
                      child: const Text(
                        '© OpenStreetMap contributors · © CARTO · tiles cached',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textDim,
                          fontSize: 7.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    color: AppColors.background.withValues(alpha: 0.75),
                    child: Text(
                      context.tr('map_data_warning').split('.').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 7.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.marker,
    required this.showLabel,
    required this.animation,
    this.onTap,
  });

  final MapMarkerData marker;
  final bool showLabel;
  final Animation<double> animation;
  final void Function(MapMarkerData)? onTap;

  Color get _color =>
      marker.color ??
      switch (marker.kind) {
        MapMarkerKind.sos => AppColors.red,
        MapMarkerKind.hazard => AppColors.amber,
        MapMarkerKind.shelter => AppColors.green,
        MapMarkerKind.node => AppColors.cyan,
        MapMarkerKind.user => AppColors.blue,
        MapMarkerKind.risk => AppColors.red,
      };

  IconData get _icon => switch (marker.kind) {
    MapMarkerKind.sos => Icons.sos_rounded,
    MapMarkerKind.hazard => Icons.warning_amber_rounded,
    MapMarkerKind.shelter => Icons.home_rounded,
    MapMarkerKind.node => Icons.hub_rounded,
    MapMarkerKind.user => Icons.my_location_rounded,
    MapMarkerKind.risk => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final core = GestureDetector(
      onTap: onTap == null ? null : () => onTap!(marker),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(color: _color, width: 2),
          boxShadow: [
            BoxShadow(color: _color.withValues(alpha: 0.45), blurRadius: 12),
          ],
        ),
        child: Icon(_icon, size: 17, color: _color),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (marker.pulse)
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 34 + animation.value * 24,
                    height: 34 + animation.value * 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color.withValues(
                          alpha: (1 - animation.value) * 0.5,
                        ),
                      ),
                    ),
                  ),
                  child!,
                ],
              );
            },
            child: core,
          )
        else
          core,
        if (showLabel) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _color.withValues(alpha: 0.4)),
            ),
            child: Text(
              marker.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w600,
                color: _color,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.textMuted),
      ),
    );
  }
}
