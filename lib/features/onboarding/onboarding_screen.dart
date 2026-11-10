import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_state.dart';
import '../../widgets/brand.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardData(
      icon: Icons.wifi_tethering_rounded,
      accent: AppColors.cyan,
      titleKey: 'onboard_title_1',
      bodyKey: 'onboard_body_1',
      tag: '01 · OFFLINE MESH',
    ),
    _OnboardData(
      icon: Icons.hub_rounded,
      accent: AppColors.blue,
      titleKey: 'onboard_title_2',
      bodyKey: 'onboard_body_2',
      tag: '02 · STORE & FORWARD',
    ),
    _OnboardData(
      icon: Icons.insights_rounded,
      accent: AppColors.green,
      titleKey: 'onboard_title_3',
      bodyKey: 'onboard_body_3',
      tag: '03 · EXPLAINABLE',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await context.read<AppState>().completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  const MeshLogo(size: 34),
                  const SizedBox(width: 9),
                  const Text(
                    'ResQMesh',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      context.tr('skip'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Center(
                              child: _OnboardIllustration(
                                icon: page.icon,
                                accent: page.accent,
                                index: index,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              page.tag,
                              style: TextStyle(
                                fontSize: 9,
                                color: page.accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr(page.titleKey),
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr(page.bodyKey),
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.55,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: i == _page ? 22 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.cyan
                            : AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  const Spacer(),
                  GradientButton(
                    label: _page == _pages.length - 1
                        ? context.tr('get_started')
                        : context.tr('continue'),
                    icon: _page == _pages.length - 1
                        ? Icons.arrow_forward_rounded
                        : null,
                    onPressed: () async {
                      if (_page == _pages.length - 1) {
                        await _finish();
                      } else {
                        await _controller.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    expand: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardIllustration extends StatelessWidget {
  const _OnboardIllustration({
    required this.icon,
    required this.accent,
    required this.index,
  });

  final IconData icon;
  final Color accent;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.2, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(scale: 0.92 + value * 0.08, child: child);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 245,
            height: 245,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.16),
                  accent.withValues(alpha: 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          for (var i = 0; i < 3; i++)
            Container(
              width: 150 + i * 34,
              height: 150 + i * 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.12 - i * 0.02),
                ),
              ),
            ),
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 34,
                ),
              ],
            ),
            child: Icon(icon, size: 54, color: accent),
          ),
          Positioned(
            right: 8,
            top: 30,
            child: _OrbitDot(color: accent, size: 12),
          ),
          Positioned(
            left: 4,
            bottom: 46,
            child: _OrbitDot(color: accent.withValues(alpha: 0.7), size: 8),
          ),
          Positioned(
            right: 30,
            bottom: 10,
            child: _OrbitDot(color: accent.withValues(alpha: 0.5), size: 6),
          ),
        ],
      ),
    );
  }
}

class _OrbitDot extends StatelessWidget {
  const _OrbitDot({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _OnboardData {
  const _OnboardData({
    required this.icon,
    required this.accent,
    required this.titleKey,
    required this.bodyKey,
    required this.tag,
  });

  final IconData icon;
  final Color accent;
  final String titleKey;
  final String bodyKey;
  final String tag;
}
