import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JarvisTheme {
  static const bg = Color(0xFF02060C);
  static const navy = Color(0xFF07111C);
  static const surface = Color(0xFF0A1522);
  static const surfaceAlt = Color(0xFF0E1C2E);
  static const cyan = Color(0xFF3DE7FF);
  static const cyanBright = Color(0xFF7AF3FF);
  static const cyanDim = Color(0xFF1A8FA3);
  static const cyanDeep = Color(0xFF0A5A6C);
  static const ink = Color(0xFFEAF7FF);
  static const inkSoft = Color(0xFFB7D0E0);
  static const muted = Color(0xFF6F8BA0);
  static const line = Color(0x553DE7FF);
  static const danger = Color(0xFFFF5C7A);
  static const ok = Color(0xFF3DFFB0);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: cyanDim,
        surface: surface,
        error: danger,
        onPrimary: bg,
        onSurface: ink,
      ),
    );

    final body = GoogleFonts.rajdhaniTextTheme(base.textTheme).apply(
      bodyColor: inkSoft,
      displayColor: ink,
    );
    final display = GoogleFonts.orbitronTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: display.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 6,
          color: cyan,
        ),
        headlineLarge: display.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 5,
          color: cyan,
        ),
        headlineMedium: display.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 3,
          color: cyan,
        ),
        titleLarge: display.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 3.5,
          color: cyan,
        ),
        titleMedium: body.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: ink,
        ),
        labelLarge: body.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          color: cyan,
        ),
        labelSmall: body.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: muted,
        ),
      ),
      dividerColor: line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt.withValues(alpha: 0.85),
        hintStyle: GoogleFonts.rajdhani(color: muted, fontWeight: FontWeight.w500),
        labelStyle: GoogleFonts.rajdhani(color: muted, letterSpacing: 1.2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: cyan.withValues(alpha: 0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: cyan, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyan.withValues(alpha: 0.18),
          foregroundColor: cyanBright,
          disabledBackgroundColor: cyan.withValues(alpha: 0.08),
          elevation: 0,
          side: BorderSide(color: cyan.withValues(alpha: 0.55)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: GoogleFonts.orbitron(
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cyan,
          textStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceAlt,
        contentTextStyle: GoogleFonts.rajdhani(color: ink, fontSize: 15),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
