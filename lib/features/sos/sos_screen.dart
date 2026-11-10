import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/status_styles.dart';
import '../../core/utilities/formatters.dart';
import '../../models/enums.dart';
import '../../models/geo_fix.dart';
import '../../models/incident.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/offline_map_view.dart';
import '../incident/incident_detail_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _descController = TextEditingController();
  final _peopleController = TextEditingController(text: '1');

  EmergencyCategory _category = EmergencyCategory.flood;
  Severity _severity = Severity.high;
  bool _manual = false;
  bool _busy = false;
  bool _acquiring = false;
  String? _locationMessage;
  GeoFix? _fix;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _fix = state.currentLocation;
    _syncControllers();
    if (_fix == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _acquire());
    }
  }

  void _syncControllers() {
    final fix = _fix;
    if (fix != null) {
      _latController.text = fix.latitude.toStringAsFixed(6);
      _lngController.text = fix.longitude.toStringAsFixed(6);
      _landmarkController.text = fix.description;
    }
  }

  Future<void> _acquire() async {
    setState(() => _acquiring = true);
    final state = context.read<AppState>();
    final attempt = await state.acquireLocation();
    if (!mounted) return;
    setState(() {
      _acquiring = false;
      _locationMessage = attempt.message;
      _fix = attempt.fix ?? _fix;
      _manual = attempt.fix == null || attempt.usedFallback;
      _syncControllers();
    });
  }

  GeoFix? _resolvedLocation() {
    if (!_manual) return _fix;
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
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
      description: _landmarkController.text.trim(),
    );
  }

  Future<void> _send() async {
    final location = _resolvedLocation();
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_valid_coords'))),
      );
      return;
    }
    final people = int.tryParse(_peopleController.text.trim()) ?? 1;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('sos_confirm_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('sos_confirm_body')),
            const SizedBox(height: 10),
            Text(
              context.tr('sos_final_warning'),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('sos_send')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final incident = await state.createSos(
        category: _category,
        severity: _severity,
        peopleAffected: people.clamp(0, 100000),
        description: _descController.text.trim(),
        location: location,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _showSent(incident);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('error_save')} $error')),
      );
    }
  }

  Future<void> _showSent(Incident incident) async {
    final state = context.read<AppState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.green, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                state.isDemo
                    ? context.tr('demo_sos_note')
                    : context.tr('sos_sent'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.isDemo
                    ? context.tr('demo_disclaimer')
                    : (state.lastMeshAction ?? context.tr('delivery_disclaimer')),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlineAction(
                      icon: Icons.map_rounded,
                      label: context.tr('open_map'),
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) =>
                                IncidentDetailScreen(incident: incident),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: GradientButton(
                      label: context.tr('done'),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ID ${shortId(incident.id)}',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textDim,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _landmarkController.dispose();
    _descController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final location = _resolvedLocation();
    return PageScaffold(
      title: context.tr('sos_title'),
      subtitle: context.tr('sos_subtitle'),
      bottom: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
                  const Icon(Icons.lock_rounded,
                      color: AppColors.green, size: 13),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      context.tr('delivery_disclaimer'),
                      style: const TextStyle(
                        fontSize: 8.5,
                        height: 1.35,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GradientButton(
                label: context.tr('sos_send'),
                icon: Icons.wifi_tethering_rounded,
                gradient: AppColors.gradientEmergency,
                height: 54,
                busy: _busy,
                onPressed: _busy ? null : _send,
              ),
            ],
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isDemo) const DemoBanner(),
            if (state.isDemo) const SizedBox(height: 10),
            _StepCard(
              number: '01',
              title: context.tr('sos_step_location'),
              color: AppColors.cyan,
              child: Column(
                children: [
                  if (_acquiring)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_fix != null)
                    OfflineMapView(
                      center: LatLng(_fix!.latitude, _fix!.longitude),
                      zoom: 15,
                      height: 130,
                      showControls: false,
                      showLabels: false,
                      markers: [
                        MapMarkerData(
                          latitude: _fix!.latitude,
                          longitude: _fix!.longitude,
                          kind: MapMarkerKind.user,
                          label: 'You',
                          pulse: true,
                          isDemo: state.isDemo,
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _LocationToggle(
                          label: context.tr('sos_location_auto'),
                          icon: Icons.gps_fixed_rounded,
                          selected: !_manual,
                          onTap: () => setState(() => _manual = false),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _LocationToggle(
                          label: context.tr('sos_location_manual'),
                          icon: Icons.edit_location_alt_rounded,
                          selected: _manual,
                          onTap: () => setState(() => _manual = true),
                        ),
                      ),
                    ],
                  ),
                  if (!_manual) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        StatusPill(
                          label: _fix == null
                              ? context.tr('location_required')
                              : _fix!.isLive
                                  ? context.tr('location_live')
                                  : context.tr('last_known'),
                          color: _fix == null
                              ? AppColors.red
                              : _fix!.isLive
                                  ? AppColors.green
                                  : AppColors.amber,
                          icon: _fix == null
                              ? Icons.location_off_rounded
                              : Icons.my_location_rounded,
                          dense: true,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _acquiring ? null : _acquire,
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: Text(context.tr('use_gps')),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.cyan,
                            textStyle: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    if (_fix != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${coordLabel(_fix!.latitude, _fix!.longitude)} · ±${_fix!.accuracyMeters.round()} m · ${_fix!.source.wire}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (!_fix!.isLive)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            context.tr('location_last_known_warning',
                                {'time': dateTimeLabel(_fix!.capturedAt)}),
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.amber,
                            ),
                          ),
                        ),
                    ],
                  ] else ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
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
                            controller: _lngController,
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
                      controller: _landmarkController,
                      decoration: InputDecoration(
                        labelText: context.tr('landmark'),
                        isDense: true,
                      ),
                    ),
                  ],
                  if (_locationMessage != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      _locationMessage!,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                  if (location == null && _manual)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        context.tr('enter_valid_coords'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _StepCard(
              number: '02',
              title: context.tr('sos_step_category'),
              color: AppColors.amber,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final category in EmergencyCategory.values)
                        _CategoryChip(
                          category: category,
                          selected: _category == category,
                          onTap: () => setState(() => _category = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('sos_severity'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      for (final severity in Severity.values) ...[
                        Expanded(
                          child: _SeverityChoice(
                            severity: severity,
                            selected: _severity == severity,
                            onTap: () => setState(() => _severity = severity),
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
            _StepCard(
              number: '03',
              title: context.tr('sos_step_details'),
              color: AppColors.red,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('sos_people'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      _StepperButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          final value = int.tryParse(_peopleController.text) ?? 1;
                          if (value > 0) {
                            _peopleController.text = '${value - 1}';
                            setState(() {});
                          }
                        },
                      ),
                      SizedBox(
                        width: 48,
                        child: TextField(
                          controller: _peopleController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      _StepperButton(
                        icon: Icons.add_rounded,
                        onTap: () {
                          final value = int.tryParse(_peopleController.text) ?? 1;
                          if (value < 100000) {
                            _peopleController.text = '${value + 1}';
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: context.tr('sos_description'),
                      hintText: context.tr('sos_desc_hint'),
                      alignLabelWithHint: true,
                    ),
                  ),
                  InfoBanner(
                    icon: Icons.visibility_off_outlined,
                    color: AppColors.amber,
                    message: state.isDemo
                        ? context.tr('demo_sos_note')
                        : 'Only send what you can verify. The alert is encrypted for the mesh group and stored locally.',
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

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.color,
    required this.child,
  });

  final String number;
  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LocationToggle extends StatelessWidget {
  const _LocationToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyanSoft : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.cyan : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? AppColors.cyan : AppColors.textMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.cyan : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
          color: selected ? color.withValues(alpha: 0.14) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? color : AppColors.border,
          ),
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

class _SeverityChoice extends StatelessWidget {
  const _SeverityChoice({
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  final Severity severity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(severity.labelKey),
              maxLines: 1,
              style: TextStyle(
                fontSize: 8,
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

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.cyan),
      ),
    );
  }
}
