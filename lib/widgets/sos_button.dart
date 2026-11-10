import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';

class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.size = 176,
  });

  final Future<void> Function() onPressed;
  final bool busy;
  final double size;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: true,
      label: context.tr('sos_button'),
      hint: context.tr('sos_hint'),
      child: SizedBox(
        width: size + 56,
        height: size + 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(size + 56, size + 56),
                  painter: _PulsePainter(
                    progress: _controller.value,
                    color: AppColors.red,
                    baseRadius: size / 2,
                  ),
                );
              },
            ),
            GestureDetector(
              onTap: widget.busy
                  ? null
                  : () async {
                      HapticFeedback.heavyImpact();
                      await widget.onPressed();
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.25, -0.35),
                    radius: 0.95,
                    colors: [
                      Color(0xFFFF5A6B),
                      Color(0xFFF0263D),
                      Color(0xFFA80F23),
                    ],
                    stops: [0.0, 0.58, 1.0],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFFA8B1).withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.48),
                      blurRadius: 42,
                      spreadRadius: 4,
                    ),
                    const BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 16,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.busy)
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(
                        Icons.wifi_tethering_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('sos_button'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        context.tr('sos_hint'),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 9,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.progress,
    required this.color,
    required this.baseRadius,
  });

  final double progress;
  final Color color;
  final double baseRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final shifted = (progress + i / 3) % 1.0;
      final radius = baseRadius + shifted * 28;
      paint.color = color.withValues(alpha: (1 - shifted) * 0.23);
      paint.strokeWidth = 1.1;
      canvas.drawCircle(size.center(Offset.zero), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
