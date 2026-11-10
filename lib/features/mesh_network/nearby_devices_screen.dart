import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../models/peer_device.dart';
import '../../models/protocol_simulation.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';

class NearbyDevicesScreen extends StatelessWidget {
  const NearbyDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final peers = state.peers;
    return PageScaffold(
      title: context.tr('mesh_title'),
      subtitle:
          '${state.connectedPeerCount} connected · ${state.peers.length} discovered',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isDemo) const DemoBanner(),
            if (state.isDemo) const SizedBox(height: 10),
            GlowSurface(
              accent: state.isDemo
                  ? AppColors.amber
                  : state.meshRunning
                  ? AppColors.cyan
                  : AppColors.textDim,
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color:
                              (state.isDemo ? AppColors.amber : AppColors.cyan)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          state.isDemo
                              ? Icons.science_rounded
                              : Icons.wifi_tethering_rounded,
                          color: state.isDemo
                              ? AppColors.amber
                              : AppColors.cyan,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.isDemo
                                  ? 'SIMULATED TOPOLOGY'
                                  : state.meshRunning
                                  ? context.tr('mesh_on')
                                  : context.tr('mesh_off'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              state.isDemo
                                  ? 'Scenario nodes only. No Bluetooth or Wi-Fi is active.'
                                  : state.meshStatusMessage,
                              style: const TextStyle(
                                fontSize: 10.5,
                                height: 1.35,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlineAction(
                          icon: state.meshRunning
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          label: state.isDemo
                              ? context.tr('exit_demo')
                              : state.meshRunning
                              ? context.tr('mesh_off')
                              : context.tr('enable_mesh'),
                          color: state.isDemo
                              ? AppColors.amber
                              : AppColors.cyan,
                          onPressed: state.isDemo
                              ? () => _confirmExitDemo(context, state)
                              : state.meshAvailable
                              ? () => state.toggleMesh()
                              : () => openAppSettings(),
                        ),
                      ),
                    ],
                  ),
                  if (!state.isDemo && !state.meshAvailable) ...[
                    const SizedBox(height: 10),
                    InfoBanner(
                      icon: Icons.info_outline_rounded,
                      color: AppColors.amber,
                      title: context.tr('nearby_unavailable'),
                      message: state.meshStatusMessage,
                      actionLabel: context.tr('permissions'),
                      onAction: openAppSettings,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MeshMetric(
                        label: context.tr('transport'),
                        value: state.isDemo
                            ? 'SIMULATED'
                            : state.meshAvailable
                            ? (Platform.isIOS ? 'MULTIPEER' : 'NEARBY')
                            : 'UNAVAILABLE',
                      ),
                      _MeshMetric(
                        label: context.tr('device_role'),
                        value: state.deviceName,
                      ),
                      _MeshMetric(
                        label: 'FRAMES',
                        value: '${state.messages.length}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: context.tr('nearby_devices'),
              subtitle: context.tr('scan'),
              actionLabel: state.isDemo ? context.tr('simulated') : null,
            ),
            if (peers.isEmpty)
              const GlowSurface(
                child: EmptyState(
                  icon: Icons.devices_other_rounded,
                  title: 'No peers discovered',
                  body: 'Start the mesh and keep this screen open. Nearby devices will appear here after Bluetooth / Wi-Fi discovery.',
                  compact: true,
                ),
              )
            else
              ...peers.map(
                (peer) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PeerCard(
                    peer: peer,
                    onConnect: peer.connected || peer.isDemo || state.isDemo
                        ? null
                        : () => state.connectToPeer(peer.endpointId),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _FieldTestCard(
              onOpenLab: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProtocolLabScreen()),
              ),
            ),
            const SizedBox(height: 12),
            GlowSurface(
              padding: const EdgeInsets.all(14),
              accent: AppColors.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_rounded,
                        color: AppColors.green,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        context.tr('security_keys').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    context.tr('security_note'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LabeledValue(
                    label: context.tr('device_id'),
                    value: state.deviceId,
                    monospace: true,
                    valueColor: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bluetooth / Wi-Fi peer transport (Nearby Connections on Android, MultipeerConnectivity on iOS) moves opaque bytes. Relay, signatures, expiry, duplicate suppression and acknowledgements are implemented in Dart. Delivery is best-effort, never guaranteed. Android and iOS meshes do not interoperate.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExitDemo(BuildContext context, AppState state) async {
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
    if (confirmed == true) {
      await state.exitDemo();
    }
  }
}

class _PeerCard extends StatelessWidget {
  const _PeerCard({required this.peer, this.onConnect});
  final PeerDevice peer;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final color = peer.connected ? AppColors.green : AppColors.textDim;
    return GlowSurface(
      padding: const EdgeInsets.all(13),
      accent: color,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Center(
              child: Text(
                peer.displayName.characters.first.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        peer.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (peer.isDemo) const DemoBadge(),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${peer.isDemo ? 'SIMULATED NODE' : peer.transport.wire.toUpperCase()} · ${peer.connected ? context.tr('connected') : context.tr('discovered')} · ${relativeTime(context, peer.lastSeen)}',
                  style: const TextStyle(fontSize: 9, color: AppColors.textDim),
                ),
                if (peer.deviceId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    peer.deviceId!,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontFamily: 'monospace',
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onConnect != null && !peer.connected)
            TextButton(
              onPressed: onConnect,
              child: Text(
                context.tr('connect'),
                style: const TextStyle(fontSize: 9.5),
              ),
            )
          else
            StatusPill(
              label: peer.connected
                  ? context.tr('connected')
                  : context.tr('discovered'),
              color: color,
              icon: peer.connected ? Icons.link_rounded : Icons.radar_rounded,
              dense: true,
            ),
        ],
      ),
    );
  }
}

class _MeshMetric extends StatelessWidget {
  const _MeshMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.cyan,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

class _FieldTestCard extends StatelessWidget {
  const _FieldTestCard({required this.onOpenLab});
  final VoidCallback onOpenLab;

  @override
  Widget build(BuildContext context) {
    return GlowSurface(
      accent: AppColors.blue,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.science_rounded,
                  color: AppColors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.tr('field_test_title'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.tr('field_test_title')),
                    content: SingleChildScrollView(
                      child: Text(
                        '${context.tr('field_test_body')}\n\n${context.tr('three_device_steps')}',
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('close')),
                      ),
                    ],
                  ),
                ),
                child: Text(
                  context.tr('field_test'),
                  style: const TextStyle(fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            context.tr('field_test_body'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const StatusPill(
                label: 'A → B → C',
                color: AppColors.blue,
                icon: Icons.route_rounded,
                dense: true,
              ),
              const Spacer(),
              TextButton(
                onPressed: onOpenLab,
                child: Text(context.tr('protocol_lab')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProtocolLabScreen extends StatefulWidget {
  const ProtocolLabScreen({super.key});

  @override
  State<ProtocolLabScreen> createState() => _ProtocolLabScreenState();
}

class _ProtocolLabScreenState extends State<ProtocolLabScreen> {
  bool _busy = false;
  ProtocolSimulationReport? _report;

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return PageScaffold(
      title: context.tr('protocol_lab'),
      subtitle: context.tr('no_radios'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InfoBanner(
              icon: Icons.science_rounded,
              color: AppColors.amber,
              title: 'SIMULATION — NOT A RADIO TEST',
              message: 'This executes the real encryption, signature, dedupe and relay state machine with three in-memory identities. No Bluetooth, Wi-Fi, Nearby Connections or network is used.',
            ),
            const SizedBox(height: 12),
            GlowSurface(
              accent: AppColors.cyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A → B → C RELAY',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('protocol_lab_body'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: context.tr('run_simulation'),
                    icon: Icons.play_arrow_rounded,
                    busy: _busy,
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            final result = await context
                                .read<AppState>()
                                .runProtocolSimulation();
                            if (!mounted) return;
                            setState(() {
                              _busy = false;
                              _report = result;
                            });
                          },
                  ),
                ],
              ),
            ),
            if (report != null) ...[
              const SizedBox(height: 14),
              SectionHeader(
                title: context.tr('simulation_result'),
                subtitle: context.tr('no_radios'),
              ),
              GlowSurface(
                accent: report.deliveredToC ? AppColors.green : AppColors.red,
                child: Column(
                  children: [
                    Row(
                      children: [
                        StatusPill(
                          label: report.deliveredToC ? 'RELAYED' : 'FAILED',
                          color: report.deliveredToC
                              ? AppColors.green
                              : AppColors.red,
                          icon: Icons.check_circle_rounded,
                        ),
                        const Spacer(),
                        Text(
                          'HOPS ${report.hopCount} · ${report.runId}',
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: AppColors.textDim,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final step in report.steps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              step.status.name == 'success'
                                  ? Icons.check_circle_rounded
                                  : step.status.name == 'warning'
                                  ? Icons.warning_amber_rounded
                                  : Icons.cancel_rounded,
                              size: 14,
                              color: step.status.name == 'success'
                                  ? AppColors.green
                                  : step.status.name == 'warning'
                                  ? AppColors.amber
                                  : AppColors.red,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.label,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    step.detail,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      height: 1.4,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${step.atMillis}ms',
                              style: const TextStyle(
                                fontSize: 8,
                                fontFamily: 'monospace',
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            GlowSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('three_device_steps'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.6,
                      color: AppColors.textMuted,
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
