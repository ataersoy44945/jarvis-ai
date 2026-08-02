import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/jarvis_theme.dart';

class HudPanel extends StatelessWidget {
  const HudPanel({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(14),
    this.glow = true,
    this.expand = true,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final bool glow;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return CustomPaint(
      painter: _BracketPainter(glow: glow),
      child: Container(
        decoration: BoxDecoration(
          color: JarvisTheme.surface.withValues(alpha: 0.55),
          border: Border.all(color: JarvisTheme.cyan.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (title != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: JarvisTheme.cyan.withValues(alpha: 0.22)),
                  ),
                ),
                child: Text(
                  title!,
                  style: GoogleFonts.orbitron(
                    color: JarvisTheme.cyan,
                    fontSize: 11,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (expand) Expanded(child: body) else body,
          ],
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter({required this.glow});

  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 14.0;
    final paint = Paint()
      ..color = JarvisTheme.cyan.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    if (glow) {
      final g = Paint()
        ..color = JarvisTheme.cyan.withValues(alpha: 0.25)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      _brackets(canvas, size, arm, g);
    }
    _brackets(canvas, size, arm, paint);
  }

  void _brackets(Canvas canvas, Size size, double arm, Paint paint) {
    canvas.drawLine(Offset(0, arm), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(arm, 0), paint);
    canvas.drawLine(Offset(size.width - arm, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, arm), paint);
    canvas.drawLine(Offset(0, size.height - arm), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(arm, size.height), paint);
    canvas.drawLine(
      Offset(size.width - arm, size.height),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - arm),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) => oldDelegate.glow != glow;
}
