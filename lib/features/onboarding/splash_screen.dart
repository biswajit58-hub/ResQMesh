import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/brand.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.error, this.onRetry});

  final String? error;
  final Future<void> Function()? onRetry;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.1, -0.2),
            radius: 1.3,
            colors: [
              Color(0xFF0E2A3E),
              Color(0xFF071321),
              Color(0xFF040A12),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1.04).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface.withValues(alpha: 0.55),
                      border: Border.all(
                        color: AppColors.cyan.withValues(alpha: 0.32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.14),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: const Center(child: MeshLogo(size: 62)),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'ResQMesh',
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('app_tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(flex: 3),
                if (widget.error == null) ...[
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.cyan,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('boot_secure'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.red, size: 26),
                        const SizedBox(height: 8),
                        Text(
                          widget.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: widget.onRetry == null
                              ? null
                              : () => widget.onRetry!(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'OFFLINE-FIRST · NO CENTRAL SERVER',
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
