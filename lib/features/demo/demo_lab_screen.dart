import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/enums.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../mesh_network/nearby_devices_screen.dart';

class DemoLabScreen extends StatefulWidget {
  const DemoLabScreen({super.key});

  @override
  State<DemoLabScreen> createState() => _DemoLabScreenState();
}

class _DemoLabScreenState extends State<DemoLabScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final content = state.currentDemoContent;
    return PageScaffold(
      title: context.tr('demo_title'),
      subtitle: context.tr('demo_disclaimer'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isDemo) ...[
              const DemoBanner(compact: false),
              const SizedBox(height: 10),
              GlowSurface(
                accent: AppColors.amber,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science_rounded,
                            color: AppColors.amber, size: 19),
                        const SizedBox(width: 7),
                        Text(
                          content?.title ?? context.tr('demo_loaded'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      content?.summary ?? '',
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.45,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const StatusPill(
                      label: 'RADIOS DISABLED · SYNTHETIC ONLY',
                      color: AppColors.amber,
                      icon: Icons.wifi_off_rounded,
                      dense: true,
                    ),
                    const SizedBox(height: 10),
                    OutlineAction(
                      label: context.tr('exit_demo'),
                      icon: Icons.exit_to_app_rounded,
                      color: AppColors.amber,
                      onPressed: _busy ? null : () => _exit(state),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            SectionHeader(
              title: context.tr('demo_select'),
              subtitle: context.tr('demo_explain'),
            ),
            _ScenarioCard(
              scenario: DemoScenario.flood,
              icon: Icons.water_rounded,
              color: AppColors.cyan,
              title: context.tr('flood'),
              description:
                  'Mahanadi flood near Cuttack and Bhubaneswar: rooftop rescue, blocked ring road, medical need and shelter pressure.',
              active: state.settings.demoScenario == DemoScenario.flood &&
                  state.isDemo,
              busy: _busy,
              onTap: () => _activate(state, DemoScenario.flood),
            ),
            const SizedBox(height: 8),
            _ScenarioCard(
              scenario: DemoScenario.earthquake,
              icon: Icons.vibration_rounded,
              color: AppColors.amber,
              title: context.tr('earthquake'),
              description:
                  'Urban building collapse in Patia: trapped residents, fire, blocked ambulance route and mass-casualty triage.',
              active:
                  state.settings.demoScenario == DemoScenario.earthquake &&
                      state.isDemo,
              busy: _busy,
              onTap: () => _activate(state, DemoScenario.earthquake),
            ),
            const SizedBox(height: 8),
            _ScenarioCard(
              scenario: DemoScenario.landslide,
              icon: Icons.landscape_rounded,
              color: AppColors.green,
              title: context.tr('landslide'),
              description:
                  'Khandagiri hillside failure: isolated homes, buried access road, injured residents and slope instability.',
              active: state.settings.demoScenario == DemoScenario.landslide &&
                  state.isDemo,
              busy: _busy,
              onTap: () => _activate(state, DemoScenario.landslide),
            ),
            const SizedBox(height: 16),
            if (content != null && content.topologyLabels.isNotEmpty) ...[
              SectionHeader(
                title: context.tr('three_device'),
                subtitle: 'Scenario-only topology. No radios are used.',
              ),
              GlowSurface(
                padding: const EdgeInsets.all(14),
                accent: AppColors.blue,
                child: Column(
                  children: [
                    for (var i = 0; i < content.topologyLabels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.blue
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  ['A', 'B', 'C'][i],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                content.topologyLabels[i],
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            if (i < content.topologyLabels.length - 1)
                              const Icon(Icons.arrow_downward_rounded,
                                  size: 14, color: AppColors.textDim),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'This is a narrative of the intended field test, not a live radio result.',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            SectionHeader(
              title: context.tr('protocol_lab'),
              subtitle: context.tr('no_radios'),
            ),
            GlowSurface(
              padding: const EdgeInsets.all(14),
              accent: AppColors.cyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('protocol_lab_body'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.45,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GradientButton(
                    label: context.tr('protocol_lab'),
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProtocolLabScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionHeader(
              title: context.tr('field_test_title'),
              subtitle: context.tr('field_test'),
            ),
            GlowSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('field_test_body'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.45,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    context.tr('three_device_steps'),
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.65,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const InfoBanner(
                    icon: Icons.gpp_maybe_rounded,
                    color: AppColors.red,
                    message:
                        'Exit demo mode before starting real radios. Demo envelopes are refused by the real transport, so synthetic data can never enter a field mesh.',
                  ),
                ],
              ),
            ),
            if (content != null && content.rescueTeams.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionHeader(
                title: 'Rescue teams (demo)',
                subtitle: 'Synthetic unit names, positions and capabilities',
              ),
              for (final team in content.rescueTeams)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: GlowSurface(
                    padding: const EdgeInsets.all(11),
                    child: Row(
                      children: [
                        const Icon(Icons.health_and_safety_rounded,
                            size: 17, color: AppColors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                team.name,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${team.unitType} · ${team.status}',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  color: AppColors.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const DemoBadge(),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _activate(AppState state, DemoScenario scenario) async {
    setState(() => _busy = true);
    try {
      await state.activateDemo(scenario);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exit(AppState state) async {
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
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final DemoScenario scenario;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlowSurface(
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.all(14),
      accent: color,
      borderColor: active ? color.withValues(alpha: 0.55) : null,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 7),
                      StatusPill(
                        label: 'ACTIVE',
                        color: color,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            active ? Icons.check_circle_rounded : Icons.download_rounded,
            size: 20,
            color: active ? color : AppColors.textDim,
          ),
        ],
      ),
    );
  }
}
