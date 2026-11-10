import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class MeshLogo extends StatelessWidget {
  const MeshLogo({super.key, this.size = 42, this.color = AppColors.cyan});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MeshLogoPainter(color: color)),
    );
  }
}

class _MeshLogoPainter extends CustomPainter {
  _MeshLogoPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.34;
    final nodes = <Offset>[];
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      nodes.add(center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius));
    }
    final line = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final node in nodes) {
      canvas.drawLine(center, node, line);
    }
    for (var i = 0; i < nodes.length; i++) {
      canvas.drawLine(nodes[i], nodes[(i + 1) % nodes.length], line);
    }
    final glow = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, size.width * 0.16, glow);
    for (final node in nodes) {
      canvas.drawCircle(
        node,
        size.width * 0.055,
        Paint()..color = color,
      );
    }
    canvas.drawCircle(center, size.width * 0.105, Paint()..color = color);
    canvas.drawCircle(
      center,
      size.width * 0.045,
      Paint()..color = AppColors.background,
    );
  }

  @override
  bool shouldRepaint(covariant _MeshLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppColors.gradientCyan,
    this.height = 50,
    this.busy = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final double height;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : gradient,
        color: onPressed == null ? AppColors.surfaceHigh : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: (gradient == AppColors.gradientEmergency
                          ? AppColors.red
                          : AppColors.blue)
                      .withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class OutlineAction extends StatelessWidget {
  const OutlineAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.cyan,
    this.expand = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        backgroundColor: color.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.textMuted,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textMuted,
            fontFamily: monospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}
