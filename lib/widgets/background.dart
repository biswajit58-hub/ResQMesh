import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_header.dart';

class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF071321),
            AppColors.background,
            Color(0xFF040A12),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _Glow(
              color: AppColors.cyan.withValues(alpha: 0.07),
              size: 280,
            ),
          ),
          Positioned(
            bottom: 20,
            left: -140,
            child: _Glow(
              color: AppColors.blue.withValues(alpha: 0.05),
              size: 320,
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.border.withValues(alpha: 0.22);
    const gap = 34.0;
    for (var x = 12.0; x < size.width; x += gap) {
      for (var y = 12.0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 0.55, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: MeshBackground(
        child: SafeArea(
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MeshBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                child: AppHeader(
                  title: title,
                  subtitle: subtitle,
                  showBack: true,
                  trailing: actions.isEmpty
                      ? null
                      : Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
              ),
              Expanded(child: child),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }
}
