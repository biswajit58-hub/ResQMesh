import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../models/enums.dart';
import '../../models/known_device.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../demo/demo_lab_screen.dart';
import '../event_history/event_history_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PageScaffold(
      title: context.tr('settings_title'),
      subtitle: '${context.tr('device_name')}: ${state.deviceName}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(context.tr('language')),
            GlowSurface(
              padding: const EdgeInsets.all(7),
              child: Row(
                children: [
                  for (final language in AppLanguage.values)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => state.setLanguage(language),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.all(3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: state.settings.language == language
                                ? AppColors.cyanSoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: state.settings.language == language
                                  ? AppColors.cyan
                                  : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              switch (language) {
                                AppLanguage.english => context.tr('english'),
                                AppLanguage.hindi => context.tr('hindi'),
                                AppLanguage.odia => context.tr('odia'),
                              },
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: state.settings.language == language
                                    ? AppColors.cyan
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel(context.tr('device_name')),
            _SettingsTile(
              icon: Icons.perm_device_information_rounded,
              title: context.tr('device_name'),
              subtitle: state.deviceName,
              trailing: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: AppColors.textDim,
              ),
              onTap: () => _editName(context, state),
            ),
            const SizedBox(height: 16),
            _SectionLabel(context.tr('mesh_settings')),
            GlowSurface(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  SwitchListTile(
                    value: state.settings.autoConnect,
                    onChanged: state.setAutoConnect,
                    title: Text(
                      context.tr('auto_connect'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    subtitle: const Text(
                      'Nearby peers are accepted automatically for multi-hop relay.',
                      style: TextStyle(fontSize: 9.5),
                    ),
                    dense: true,
                    secondary: const Icon(
                      Icons.link_rounded,
                      size: 19,
                      color: AppColors.cyan,
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: state.settings.meshAutoStart,
                    onChanged: state.setMeshAutoStart,
                    title: Text(
                      context.tr('auto_start'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    subtitle: Text(
                      state.isDemo
                          ? 'Radios stay off while demo mode is active.'
                          : state.meshAvailable
                          ? context.tr('radio_ready')
                          : context.tr('radio_unavailable'),
                      style: const TextStyle(fontSize: 9.5),
                    ),
                    dense: true,
                    secondary: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 19,
                      color: AppColors.green,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    dense: true,
                    leading: Icon(
                      state.meshRunning
                          ? Icons.wifi_tethering_rounded
                          : Icons.portable_wifi_off_rounded,
                      size: 19,
                      color: state.meshRunning
                          ? AppColors.green
                          : AppColors.textDim,
                    ),
                    title: Text(
                      state.meshRunning
                          ? context.tr('mesh_on')
                          : context.tr('mesh_off'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    subtitle: Text(
                      state.meshStatusMessage,
                      style: const TextStyle(fontSize: 9.5),
                    ),
                    trailing: TextButton(
                      onPressed: state.isDemo ? null : state.toggleMesh,
                      child: Text(
                        state.meshRunning
                            ? context.tr('mesh_off')
                            : context.tr('enable_mesh'),
                        style: const TextStyle(fontSize: 9.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel(context.tr('group_key')),
            _SettingsTile(
              icon: Icons.key_rounded,
              title: context.tr('group_key'),
              subtitle: state.usesDefaultMeshKey
                  ? 'DEFAULT DEMO KEY — change before field use'
                  : 'Custom group passphrase set',
              subtitleColor: state.usesDefaultMeshKey
                  ? AppColors.amber
                  : AppColors.green,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.textDim,
              ),
              onTap: () => _changeKey(context, state),
            ),
            const SizedBox(height: 16),
            _SectionLabel(context.tr('security_keys')),
            GlowSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledValue(
                    label: context.tr('device_id'),
                    value: state.deviceId,
                    monospace: true,
                  ),
                  const SizedBox(height: 9),
                  LabeledValue(
                    label: context.tr('public_key'),
                    value: state.crypto.identity.publicKeyBase64,
                    monospace: true,
                    valueColor: AppColors.textDim,
                  ),
                  const SizedBox(height: 9),
                  LabeledValue(
                    label: context.tr('trust_state'),
                    value: 'TOFU pinning · Ed25519 + AES-256-GCM',
                    valueColor: AppColors.green,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    context.tr('security_note'),
                    style: const TextStyle(
                      fontSize: 9.5,
                      height: 1.45,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<KnownDevice>>(
                    future: state.knownDevices.list(demoOnly: state.isDemo),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Row(
                        children: [
                          const Icon(
                            Icons.people_alt_rounded,
                            size: 14,
                            color: AppColors.cyan,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$count pinned device(s)',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel(context.tr('diagnostics')),
            GlowSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _DiagnosticRow(
                    label: context.tr('transport'),
                    value: state.isDemo
                        ? 'SIMULATED'
                        : state.meshAvailable
                        ? (Platform.isIOS ? 'MULTIPEER' : 'NEARBY')
                        : 'UNAVAILABLE',
                  ),
                  _DiagnosticRow(
                    label: context.tr('database'),
                    value: 'SQLite · schema 1',
                  ),
                  _DiagnosticRow(
                    label: 'Messages',
                    value: '${state.messages.length}',
                  ),
                  _DiagnosticRow(
                    label: context.tr('event_count', {
                      'count': state.events.length,
                    }),
                    value: '${state.events.length}',
                  ),
                  _DiagnosticRow(
                    label: context.tr('nearby_devices'),
                    value:
                        '${state.connectedPeerCount} connected / ${state.peers.length} known',
                  ),
                  _DiagnosticRow(
                    label: 'Last refresh',
                    value: state.lastRefreshAt == null
                        ? '—'
                        : clockTime(state.lastRefreshAt!),
                  ),
                  _DiagnosticRow(
                    label: context.tr('app_version'),
                    value: '1.0.0 (1)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel(context.tr('permissions')),
            _SettingsTile(
              icon: Icons.admin_panel_settings_rounded,
              title: context.tr('permissions'),
              subtitle: context.tr('permissions_body'),
              trailing: const Icon(
                Icons.open_in_new_rounded,
                size: 15,
                color: AppColors.textDim,
              ),
              onTap: openAppSettings,
            ),
            _SettingsTile(
              icon: Icons.lock_rounded,
              title: context.tr('responder_pin'),
              subtitle: state.settings.responderPinConfigured
                  ? 'Local PIN configured'
                  : 'Not configured',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.textDim,
              ),
              onTap: () => _setResponderPin(context, state),
            ),
            const SizedBox(height: 16),
            _SectionLabel(context.tr('demo_lab')),
            GlowSurface(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const DemoLabScreen())),
              padding: const EdgeInsets.all(14),
              accent: AppColors.amber,
              child: Row(
                children: [
                  const Icon(
                    Icons.science_rounded,
                    color: AppColors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isDemo
                              ? context.tr('demo_mode')
                              : context.tr('demo_lab'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          context.tr('demo_explain'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textDim,
                  ),
                ],
              ),
            ),
            if (state.isDemo) ...[
              const SizedBox(height: 8),
              OutlineAction(
                icon: Icons.exit_to_app_rounded,
                label: context.tr('exit_demo'),
                color: AppColors.amber,
                onPressed: () => _exitDemo(context, state),
              ),
            ],
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.inventory_2_rounded,
              title: context.tr('history_title'),
              subtitle: context.tr('black_box_desc'),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.textDim,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EventHistoryScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel(context.tr('about')),
            GlowSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      MeshLogo(size: 28),
                      SizedBox(width: 8),
                      Text(
                        'ResQMesh 1.0.0',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'An offline peer-to-peer disaster rescue and hazard intelligence network. Not a replacement for emergency services. No delivery or safety guarantee is provided.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, AppState state) async {
    final controller = TextEditingController(text: state.deviceName);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('device_name')),
        content: TextField(
          controller: controller,
          maxLength: 32,
          decoration: const InputDecoration(labelText: 'ResQ-…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await state.setDeviceName(controller.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$error')));
                }
              }
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _changeKey(BuildContext context, AppState state) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('change_key')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Every phone that should relay your messages must use the SAME network key. Changing it makes new traffic unreadable to devices on the old key. Share it out of band — never in a public chat.',
              style: TextStyle(fontSize: 11.5, height: 1.45),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New network passphrase (12+ chars)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await state.setGroupPassphrase(controller.text);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Network key updated. Restart the mesh and share the key with trusted peers.',
              ),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    }
    controller.dispose();
  }

  Future<void> _setResponderPin(BuildContext context, AppState state) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('responder_pin')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: context.tr('set_pin'),
                counterText: '',
              ),
            ),
            Text(
              context.tr('local_gate_warning'),
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.4,
                color: AppColors.textDim,
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
              try {
                await state.setResponderPin(controller.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$error')));
                }
              }
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _exitDemo(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('exit_demo')),
        content: Text(context.tr('demo_exit_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
    if (confirmed == true) await state.exitDemo();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 3),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.textDim,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.subtitleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlowSurface(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: AppColors.cyan),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.35,
                      color: subtitleColor ?? AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 9.5, color: AppColors.textDim),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 9.5,
              fontFamily: 'monospace',
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
