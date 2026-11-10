import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/status_styles.dart';
import '../../models/enums.dart';
import '../../models/geo_fix.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/offline_map_view.dart';

class HazardReportScreen extends StatefulWidget {
  const HazardReportScreen({super.key});

  @override
  State<HazardReportScreen> createState() => _HazardReportScreenState();
}

class _HazardReportScreenState extends State<HazardReportScreen> {
  final _description = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _landmark = TextEditingController();
  EmergencyCategory _category = EmergencyCategory.flood;
  Severity _severity = Severity.high;
  GeoFix? _fix;
  bool _manual = false;
  bool _busy = false;
  bool _acquiring = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _fix = context.read<AppState>().currentLocation;
    _sync();
    if (_fix == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _acquire());
    }
  }

  void _sync() {
    if (_fix == null) return;
    _lat.text = _fix!.latitude.toStringAsFixed(6);
    _lng.text = _fix!.longitude.toStringAsFixed(6);
    _landmark.text = _fix!.description;
  }

  Future<void> _acquire() async {
    setState(() => _acquiring = true);
    final attempt = await context.read<AppState>().acquireLocation();
    if (!mounted) return;
    setState(() {
      _acquiring = false;
      _message = attempt.message;
      _fix = attempt.fix ?? _fix;
      _manual = attempt.fix == null || attempt.usedFallback;
      _sync();
    });
  }

  GeoFix? _location() {
    if (!_manual) return _fix;
    final lat = double.tryParse(_lat.text);
    final lng = double.tryParse(_lng.text);
    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    return GeoFix(
      latitude: lat,
      longitude: lng,
      accuracyMeters: 500,
      source: LocationSource.manual,
      capturedAt: DateTime.now().toUtc(),
      description: _landmark.text.trim(),
    );
  }

  Future<void> _submit() async {
    final location = _location();
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_valid_coords'))),
      );
      return;
    }
    if (_description.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('hazard_desc_hint'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().createHazard(
            category: _category,
            severity: _severity,
            description: _description.text.trim(),
            location: location,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('hazard_received'))),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('error_save')} $error')),
      );
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _lat.dispose();
    _lng.dispose();
    _landmark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fix = _location();
    return PageScaffold(
      title: context.tr('hazard_title'),
      subtitle: context.tr('hazard_subtitle'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isDemo) ...[
              const DemoBanner(),
              const SizedBox(height: 10),
            ],
            if (fix != null)
              Stack(
                children: [
                  OfflineMapView(
                    center: LatLng(fix.latitude, fix.longitude),
                    zoom: 15,
                    height: 150,
                    showControls: false,
                    markers: [
                      MapMarkerData(
                        latitude: fix.latitude,
                        longitude: fix.longitude,
                        kind: MapMarkerKind.hazard,
                        label: context.tr(_category.labelKey),
                        color: categoryColor(_category),
                        pulse: true,
                      ),
                    ],
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: StatusPill(
                      label: fix.isLive
                          ? context.tr('location_live')
                          : context.tr('last_known'),
                      color: fix.isLive ? AppColors.green : AppColors.amber,
                      icon: Icons.my_location_rounded,
                      dense: true,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            GlowSurface(
              accent: AppColors.amber,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('hazard_category').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final category in EmergencyCategory.values)
                        _HazardCategory(
                          category: category,
                          selected: _category == category,
                          onTap: () => setState(() => _category = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('sos_severity').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      for (final severity in Severity.values) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _severity = severity),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _severity == severity
                                    ? severityColor(severity)
                                        .withValues(alpha: 0.14)
                                    : AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _severity == severity
                                      ? severityColor(severity)
                                      : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  context.tr(severity.labelKey),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: _severity == severity
                                        ? severityColor(severity)
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (severity != Severity.values.last)
                          const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GlowSurface(
              child: TextField(
                controller: _description,
                minLines: 4,
                maxLines: 7,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: context.tr('hazard_desc'),
                  hintText: context.tr('hazard_desc_hint'),
                  alignLabelWithHint: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 10),
            GlowSurface(
              accent: AppColors.cyan,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('location'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _acquiring ? null : _acquire,
                        child: Text(context.tr('use_gps')),
                      ),
                    ],
                  ),
                  if (_acquiring)
                    const LinearProgressIndicator(minHeight: 2),
                  Row(
                    children: [
                      Expanded(
                        child: _LocationMode(
                          selected: !_manual,
                          label: context.tr('sos_location_auto'),
                          onTap: () => setState(() => _manual = false),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _LocationMode(
                          selected: _manual,
                          label: context.tr('sos_location_manual'),
                          onTap: () => setState(() => _manual = true),
                        ),
                      ),
                    ],
                  ),
                  if (_manual) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lat,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: InputDecoration(
                              labelText: context.tr('latitude'),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lng,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: InputDecoration(
                              labelText: context.tr('longitude'),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _landmark,
                      decoration: InputDecoration(
                        labelText: context.tr('landmark'),
                        isDense: true,
                      ),
                    ),
                  ] else if (fix != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)} · ±${fix.accuracyMeters.round()} m',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const InfoBanner(
              icon: Icons.verified_user_outlined,
              color: AppColors.amber,
              message:
                  'Your report is an observation, not a prediction. Other independent reports may corroborate it. Forwarded copies are not counted as new confirmations.',
            ),
            const SizedBox(height: 14),
            GradientButton(
              label: context.tr('hazard_submit'),
              icon: Icons.add_alert_rounded,
              gradient: AppColors.gradientCyan,
              busy: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _HazardCategory extends StatelessWidget {
  const _HazardCategory({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final EmergencyCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.13) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIcon(category),
                size: 14, color: selected ? color : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              context.tr(category.labelKey),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationMode extends StatelessWidget {
  const _LocationMode({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyanSoft : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.cyan : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.cyan : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
