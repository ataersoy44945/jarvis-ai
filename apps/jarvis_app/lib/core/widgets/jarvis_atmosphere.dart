import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Stark-style layered backdrop with bloom + faint radial grid.
class JarvisAtmosphere extends StatelessWidget {
  const JarvisAtmosphere({super.key, required this.child, this.intensity = 1});

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: JarvisTheme.bg),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.05,
              colors: [
                Color.lerp(JarvisTheme.navy, JarvisTheme.cyanDeep, 0.35 * intensity)!,
                JarvisTheme.bg,
              ],
              stops: const [0.0, 0.78],
            ),
          ),
        ),
        CustomPaint(
          painter: _HudGridPainter(alpha: 0.055 * intensity),
          child: const SizedBox.expand(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Colors.transparent,
                JarvisTheme.bg.withValues(alpha: 0.72),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _HudGridPainter extends CustomPainter {
  _HudGridPainter({required this.alpha});

  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = JarvisTheme.cyan.withValues(alpha: alpha);

    for (var i = 1; i <= 8; i++) {
      canvas.drawCircle(center, size.shortestSide * 0.08 * i, paint);
    }

    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(a) * size.shortestSide,
          center.dy + math.sin(a) * size.shortestSide,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HudGridPainter oldDelegate) => oldDelegate.alpha != alpha;
}
