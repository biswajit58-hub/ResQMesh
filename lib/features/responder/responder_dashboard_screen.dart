import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/status_styles.dart';
import '../../core/utilities/formatters.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../models/priority_assessment.dart';
import '../../services/app_state.dart';
import '../../widgets/background.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../incident/incident_detail_screen.dart';
import '../shelters/shelter_screen.dart';

class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() =>
      _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen> {
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_pin.text.trim().length < 4) {
      setState(() => _error = context.tr('pin_required'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<AppState>().loginResponder(_pin.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Invalid responder PIN.';
    });
    if (ok) _pin.clear();
  }

  Future<void> _setAndLogin() async {
    if (_pin.text.trim().length < 4) {
      setState(() => _error = context.tr('pin_required'));
      return;
    }
    if (_pin.text.trim() != _confirmPin.text.trim()) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      await state.setResponderPin(_pin.text.trim());
      final ok = await state.loginResponder(_pin.text.trim());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ok ? null : 'Could not open a session.';
      });
      _pin.clear();
      _confirmPin.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PageScaffold(
      title: context.tr('responder_title'),
      subtitle: state.isResponder
          ? context.tr('session_active')
          : context.tr('local_gate_warning'),
      child: state.isResponder
          ? _buildDashboard(context, state)
          : _buildLogin(context, state),
    );
  }

  Widget _buildLogin(BuildContext context, AppState state) {
    final hasPin = state.settings.responderPinConfigured;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlowSurface(
            accent: AppColors.amber,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(Icons.badge_rounded,
                      color: AppColors.amber, size: 27),
                ),
                const SizedBox(height: 12),
                Text(
                  hasPin
                      ? context.tr('responder_login')
                      : context.tr('set_pin'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr('local_gate_warning'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlowSurface(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: InputDecoration(
                    labelText: context.tr('responder_pin'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    counterText: '',
                  ),
                  onSubmitted: (_) => hasPin ? _login() : null,
                ),
                if (!hasPin) ...[
                  const SizedBox(height: 9),
                  TextField(
                    controller: _confirmPin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    decoration: InputDecoration(
                      labelText: 'Confirm PIN',
                      prefixIcon:
                          const Icon(Icons.lock_reset_rounded, size: 18),
                      counterText: '',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.red,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                GradientButton(
                  label: hasPin ? context.tr('continue') : context.tr('set_pin'),
                  icon: Icons.login_rounded,
                  busy: _busy,
                  onPressed: hasPin ? _login : _setAndLogin,
                ),
                if (state.isDemo) ...[
                  const SizedBox(height: 9),
                  const Text(
                    'DEMO HINT: choose a PIN such as 2468 for the walkthrough. It is stored only on this device with PBKDF2.',
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.4,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            icon: Icons.gpp_maybe_outlined,
            color: AppColors.red,
            title: 'NOT AN OFFICIAL CREDENTIAL',
            message:
                'This local PIN gates responder actions on this device. ResQMesh does not verify government, hospital or agency identity. In a real deployment, integrate an agency-issued credential and signature.',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, AppState state) {
    final triage = [...state.activeIncidents];
    triage.sort((a, b) {
      final aScore = state.assessmentFor(a.id)?.score ?? 0;
      final bScore = state.assessmentFor(b.id)?.score ?? 0;
      return bScore.compareTo(aScore);
    });
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlowSurface(
            padding: const EdgeInsets.all(14),
            accent: AppColors.green,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      color: AppColors.green, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('session_active'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${context.tr('local_gate_warning')} · ${state.deviceName}',
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: state.logoutResponder,
                  child: Text(context.tr('logout')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionHeader(
            title: context.tr('triage_queue'),
            subtitle: context.tr('dispatch_note'),
            actionLabel: context.tr('shelters'),
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShelterScreen()),
            ),
          ),
          if (triage.isEmpty)
            GlowSurface(
              child: EmptyState(
                icon: Icons.task_alt_rounded,
                title: context.tr('no_queue'),
                compact: true,
              ),
            )
          else
            ...triage.map(
              (incident) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _TriageCard(
                  incident: incident,
                  priority: state.assessmentFor(incident.id),
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          IncidentDetailScreen(incident: incident),
                    ),
                  ),
                  onStatus: (status) async {
                    await state.updateIncidentStatus(incident, status);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${incident.category.wire} → ${status.wire}',
                          ),
                        ),
                      );
                    }
                  },
                  onVerify: () async {
                    await state.addResponderVote(
                      incidentId: incident.id,
                      state: VerificationState.responderVerified,
                      note: 'Responder verification from dashboard.',
                    );
                  },
                  onDispute: () async {
                    await state.addResponderVote(
                      incidentId: incident.id,
                      state: VerificationState.disputed,
                      note: 'Responder dispute from dashboard.',
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),
          GlowSurface(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('responder_note').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textDim,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Actions are written to the local black box. "Responder verified" is a local role-gated claim, not a verified agency credential.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TriageCard extends StatelessWidget {
  const _TriageCard({
    required this.incident,
    required this.priority,
    required this.onOpen,
    required this.onStatus,
    required this.onVerify,
    required this.onDispute,
  });

  final Incident incident;
  final PriorityAssessment? priority;
  final VoidCallback onOpen;
  final Future<void> Function(IncidentStatus) onStatus;
  final Future<void> Function() onVerify;
  final Future<void> Function() onDispute;

  @override
  Widget build(BuildContext context) {
    final band = priority?.band ?? PriorityBand.routine;
    final color = priorityColor(band);
    return GlowSurface(
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      accent: color,
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    priority?.score.toStringAsFixed(0) ?? '—',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
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
                            context.tr(incident.category.labelKey),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (incident.isDemo) const DemoBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${incident.peopleAffected} ${context.tr('people_affected')} · ${relativeTime(context, incident.createdAt)} · ${context.tr(incident.verification.labelKey)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: context.tr(band.labelKey),
                color: color,
                dense: true,
              ),
            ],
          ),
          if (incident.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              incident.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              _ActionChip(
                label: context.tr('mark_ack'),
                color: AppColors.cyan,
                icon: Icons.check_rounded,
                onTap: () => onStatus(IncidentStatus.acknowledged),
              ),
              _ActionChip(
                label: context.tr('mark_responding'),
                color: AppColors.amber,
                icon: Icons.directions_run_rounded,
                onTap: () => onStatus(IncidentStatus.responding),
              ),
              _ActionChip(
                label: context.tr('mark_resolved'),
                color: AppColors.green,
                icon: Icons.task_alt_rounded,
                onTap: () => onStatus(IncidentStatus.resolved),
              ),
              _ActionChip(
                label: context.tr('mark_verified'),
                color: AppColors.green,
                icon: Icons.verified_rounded,
                onTap: onVerify,
              ),
              _ActionChip(
                label: context.tr('mark_disputed'),
                color: AppColors.red,
                icon: Icons.gavel_rounded,
                onTap: onDispute,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
