import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/voice_service.dart';
import '../../core/theme/jarvis_theme.dart';

class AiSphere extends StatefulWidget {
  const AiSphere({super.key, required this.state, this.size = 220});

  final VoiceState state;
  final double size;

  @override
  State<AiSphere> createState() => _AiSphereState();
}

class _AiSphereState extends State<AiSphere> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intensity = switch (widget.state) {
      VoiceState.idle => 0.35,
      VoiceState.listening => 0.85,
      VoiceState.thinking => 0.65,
      VoiceState.speaking => 1.0,
    };

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _SpherePainter(
              t: _ctrl.value,
              intensity: intensity,
              state: widget.state,
            ),
          ),
        );
      },
    );
  }
}

class _SpherePainter extends CustomPainter {
  _SpherePainter({
    required this.t,
    required this.intensity,
    required this.state,
  });

  final double t;
  final double intensity;
  final VoiceState state;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.32;

    final glow = Paint()
      ..color = JarvisTheme.cyan.withValues(alpha: 0.12 + intensity * 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(center, radius * (1.55 + intensity * 0.25), glow);

    final pulse = 1 + math.sin(t * math.pi * 2) * 0.04 * intensity;
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(JarvisTheme.cyan, Colors.white, 0.35)!,
          JarvisTheme.cyanDim,
          const Color(0xFF0A1A28),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * pulse));
    canvas.drawCircle(center, radius * pulse, corePaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = JarvisTheme.cyan.withValues(alpha: 0.35 + intensity * 0.4);
    canvas.drawCircle(center, radius * 1.18, ringPaint);

    final orbitR = radius * 1.35;
    for (var i = 0; i < 3; i++) {
      final angle = t * math.pi * 2 * (1 + i * 0.25) + i * 1.7;
      final p = Offset(
        center.dx + math.cos(angle) * orbitR,
        center.dy + math.sin(angle) * orbitR * 0.55,
      );
      canvas.drawCircle(
        p,
        3.2 + intensity * 2,
        Paint()..color = JarvisTheme.cyan.withValues(alpha: 0.7),
      );
    }

    if (state == VoiceState.listening || state == VoiceState.speaking) {
      final wave = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = JarvisTheme.cyan.withValues(alpha: 0.25);
      for (var i = 0; i < 3; i++) {
        final r = radius * (1.4 + i * 0.18 + math.sin((t + i) * math.pi * 2) * 0.05);
        canvas.drawCircle(center, r, wave);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpherePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.intensity != intensity ||
        oldDelegate.state != state;
  }
}
