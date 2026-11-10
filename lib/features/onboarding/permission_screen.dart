import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  List<Permission> get _permissions => Platform.isIOS
      ? <Permission>[Permission.locationWhenInUse]
      : <Permission>[
          Permission.locationWhenInUse,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.nearbyWifiDevices,
        ];

  final Map<Permission, PermissionStatus> _status = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    for (final permission in _permissions) {
      try {
        _status[permission] = await permission.status;
      } catch (_) {
        _status[permission] = PermissionStatus.denied;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      final results = await _permissions.request();
      _status.addAll(results);
    } catch (_) {
      // Permission APIs are unavailable on some platforms; continue in
      // limited mode rather than blocking local emergency records.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final state = context.read<AppState>();
    await state.completePermissions();
  }

  Future<void> _skip() async {
    final state = context.read<AppState>();
    await state.completePermissions();
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    final locationOk =
        _status[Permission.locationWhenInUse]?.isGranted ?? false;
    final nearbyOk =
        !isIOS &&
        (_status[Permission.bluetoothScan]?.isGranted ?? false) &&
        (_status[Permission.bluetoothConnect]?.isGranted ?? false) &&
        (_status[Permission.bluetoothAdvertise]?.isGranted ?? false);
    return AppScaffold(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: MeshLogo(size: 38),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('perm_title'),
                    style: const TextStyle(
                      fontSize: 29,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('perm_body'),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _PermissionCard(
                    icon: Icons.gps_fixed_rounded,
                    color: AppColors.cyan,
                    title: context.tr('perm_gps'),
                    body: context.tr('perm_gps_body'),
                    granted: locationOk,
                  ),
                  const SizedBox(height: 10),
                  if (isIOS)
                    const InfoBanner(
                      icon: Icons.hub_rounded,
                      color: AppColors.blue,
                      title: 'Nearby devices & Local Network',
                      message: 'iOS asks for Bluetooth and Local Network access when you start the mesh. Allow both prompts — there are no Android-style Nearby permissions to grant here.',
                    )
                  else
                    _PermissionCard(
                      icon: Icons.hub_rounded,
                      color: AppColors.blue,
                      title: context.tr('perm_nearby'),
                      body: context.tr('perm_nearby_body'),
                      granted: nearbyOk,
                      requiredForMesh: true,
                    ),
                  const SizedBox(height: 18),
                  const InfoBanner(
                    icon: Icons.lock_outline_rounded,
                    color: AppColors.green,
                    message: 'SOS and hazard reports are stored locally even if every permission is denied. Peer relay requires Bluetooth / Wi-Fi permissions.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: context.tr('allow'),
            icon: Icons.shield_rounded,
            busy: _busy,
            onPressed: _request,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _skip,
            child: Text(
              context.tr('skip'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.granted,
    this.requiredForMesh = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool granted;
  final bool requiredForMesh;

  @override
  Widget build(BuildContext context) {
    return GlowSurface(
      padding: const EdgeInsets.all(14),
      accent: color,
      borderColor: granted
          ? AppColors.green.withValues(alpha: 0.28)
          : AppColors.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (granted)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.green,
                        size: 18,
                      )
                    else
                      const Icon(
                        Icons.circle_outlined,
                        color: AppColors.textDim,
                        size: 17,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
                if (requiredForMesh) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'REQUIRED FOR REAL P2P RELAY',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
