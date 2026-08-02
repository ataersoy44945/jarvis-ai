import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/jarvis_theme.dart';

class HudArcGauge extends StatelessWidget {
  const HudArcGauge({
    super.key,
    required this.value,
    required this.label,
    this.sublabel,
    this.size = 96,
  });

  /// 0..1
  final double value;
  final String label;
  final String? sublabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArcPainter(progress: v),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(v * 100).round()}%',
                style: GoogleFonts.orbitron(
                  color: JarvisTheme.cyanBright,
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.rajdhani(
                  color: JarvisTheme.muted,
                  fontSize: size * 0.12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: GoogleFonts.rajdhani(
                    color: JarvisTheme.cyanDim,
                    fontSize: size * 0.1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.42;
    const start = -math.pi * 0.75;
    const sweep = math.pi * 1.5;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = JarvisTheme.cyan.withValues(alpha: 0.15)
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = JarvisTheme.cyan
      ..strokeCap = StrokeCap.butt
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * progress,
      false,
      fill,
    );

    // Tick marks
    final tick = Paint()
      ..color = JarvisTheme.cyan.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 0; i <= 12; i++) {
      final a = start + sweep * (i / 12);
      final inner = Offset(
        center.dx + math.cos(a) * (radius - 6),
        center.dy + math.sin(a) * (radius - 6),
      );
      final outer = Offset(
        center.dx + math.cos(a) * (radius + 2),
        center.dy + math.sin(a) * (radius + 2),
      );
      canvas.drawLine(inner, outer, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) => oldDelegate.progress != progress;
}
