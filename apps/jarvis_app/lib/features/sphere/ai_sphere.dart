import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/audio/voice_service.dart';
import '../../core/theme/jarvis_theme.dart';

/// Multi-ring Stark-style HUD core. Tap toggles listening when [onTap] set.
class HudCore extends StatefulWidget {
  const HudCore({
    super.key,
    required this.state,
    this.size = 280,
    this.onTap,
  });

  final VoiceState state;
  final double size;
  final VoidCallback? onTap;

  @override
  State<HudCore> createState() => _HudCoreState();
}

class _HudCoreState extends State<HudCore> with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant HudCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      final hot = widget.state == VoiceState.listening || widget.state == VoiceState.speaking;
      _spin.duration = Duration(milliseconds: hot ? 4500 : 12000);
      if (!_spin.isAnimating) _spin.repeat();
      _breath.duration = Duration(milliseconds: hot ? 800 : 2400);
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intensity = switch (widget.state) {
      VoiceState.idle => 0.4,
      VoiceState.listening => 0.9,
      VoiceState.thinking => 0.65,
      VoiceState.speaking => 1.0,
    };

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _breath]),
          builder: (context, _) {
            return CustomPaint(
              painter: _HudCorePainter(
                t: _spin.value,
                breath: _breath.value,
                intensity: intensity,
                state: widget.state,
              ),
              child: Center(
                child: Text(
                  _centerLabel(widget.state),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    color: JarvisTheme.cyanBright.withValues(alpha: 0.9),
                    fontSize: widget.size * 0.055,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _centerLabel(VoiceState state) {
    return switch (state) {
      VoiceState.idle => 'JARVIS',
      VoiceState.listening => 'LISTEN',
      VoiceState.thinking => 'THINK',
      VoiceState.speaking => 'SPEAK',
    };
  }
}

class _HudCorePainter extends CustomPainter {
  _HudCorePainter({
    required this.t,
    required this.breath,
    required this.intensity,
    required this.state,
  });

  final double t;
  final double breath;
  final double intensity;
  final VoiceState state;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final base = size.shortestSide * 0.18;
    final pulse = 1 + (breath - 0.5) * 0.06 * intensity;

    // Outer bloom
    canvas.drawCircle(
      c,
      base * 2.8 * pulse,
      Paint()
        ..color = JarvisTheme.cyan.withValues(alpha: 0.08 + intensity * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );

    // Core orb
    final orbR = base * pulse;
    canvas.drawCircle(
      c,
      orbR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            Colors.white.withValues(alpha: 0.85),
            JarvisTheme.cyanBright,
            JarvisTheme.cyan,
            const Color(0xFF041018),
          ],
          stops: const [0.0, 0.2, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: orbR)),
    );

    // Segmented rings
    _ring(canvas, c, base * 1.35, t * 1.0, 48, 0.55, 2);
    _ring(canvas, c, base * 1.7, -t * 0.7, 36, 0.4, 1.5);
    _ring(canvas, c, base * 2.05, t * 0.45, 64, 0.3, 1.2);
    _ring(canvas, c, base * 2.4, -t * 0.25, 24, 0.5, 1.8, dashed: true);

    // Radial state labels
    final labels = ['IDLE', 'LISTEN', 'THINK', 'SPEAK'];
    final active = switch (state) {
      VoiceState.idle => 0,
      VoiceState.listening => 1,
      VoiceState.thinking => 2,
      VoiceState.speaking => 3,
    };
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 2 + i * (math.pi / 2) + t * 0.15;
      final r = base * 2.55;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: i == active
                ? JarvisTheme.cyanBright
                : JarvisTheme.cyan.withValues(alpha: 0.35),
            fontSize: size.shortestSide * 0.032,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    // Activity ripples
    if (state != VoiceState.idle) {
      for (var i = 0; i < 3; i++) {
        final phase = (t * 1.5 + i * 0.28) % 1.0;
        canvas.drawCircle(
          c,
          base * (1.5 + phase * 1.2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = JarvisTheme.cyan.withValues(alpha: (0.35 - phase * 0.3) * intensity),
        );
      }
    }
  }

  void _ring(
    Canvas canvas,
    Offset c,
    double radius,
    double rot,
    int segments,
    double gapRatio,
    double stroke, {
    bool dashed = false,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = JarvisTheme.cyan.withValues(alpha: 0.55 + intensity * 0.3);

    final rect = Rect.fromCircle(center: c, radius: radius);
    final seg = (math.pi * 2) / segments;
    final draw = seg * (1 - gapRatio * (dashed ? 0.7 : 0.35));
    for (var i = 0; i < segments; i++) {
      if (dashed && i.isOdd) continue;
      canvas.drawArc(rect, rot + i * seg, draw, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HudCorePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.breath != breath ||
        oldDelegate.intensity != intensity ||
        oldDelegate.state != state;
  }
}

/// Keep old name as thin wrapper for any leftover imports.
class AiSphere extends StatelessWidget {
  const AiSphere({super.key, required this.state, this.size = 220, this.onTap});

  final VoiceState state;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HudCore(state: state, size: size, onTap: onTap);
  }
}
