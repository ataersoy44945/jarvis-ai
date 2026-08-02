import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/jarvis_theme.dart';

class HudTickRail extends StatelessWidget {
  const HudTickRail({super.key, this.days = 30});

  final int days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = now.day.clamp(1, days);

    return SizedBox(
      height: 28,
      child: Row(
        children: List.generate(days, (i) {
          final day = i + 1;
          final active = day == current;
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: active ? 10 : 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  color: active
                      ? JarvisTheme.cyan
                      : JarvisTheme.cyan.withValues(alpha: day < current ? 0.35 : 0.12),
                ),
                const SizedBox(height: 2),
                if (day == 1 || day == current || day == days || day % 5 == 0)
                  Text(
                    day.toString().padLeft(2, '0'),
                    style: GoogleFonts.orbitron(
                      fontSize: 7,
                      color: active ? JarvisTheme.cyanBright : JarvisTheme.muted,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class HudClock extends StatelessWidget {
  const HudClock({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        final n = DateTime.now();
        final t =
            '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
        return Text(
          t,
          style: GoogleFonts.orbitron(
            color: JarvisTheme.cyan,
            fontSize: 16,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}
