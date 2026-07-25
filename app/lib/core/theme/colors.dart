import 'package:flutter/material.dart';

/// Palette matching the original QML theme, extended for the KDE-glassy look.
abstract class AppColors {
  static const Color background = Color(0xFF0d1117);
  static const Color surface = Color(0xFF161b22);
  static const Color surfaceVariant = Color(0xFF21262d);
  static const Color surfaceTint = Color(0x14ffffff); // subtle white wash for glass

  static const Color primary = Color(0xFF58a6ff);
  static const Color onBackground = Color(0xFFc9d1d9);
  static const Color muted = Color(0xFF8b949e);
  static const Color accent = Color(0xFF3fb950);
  static const Color warning = Color(0xFFd29922);
  static const Color danger = Color(0xFFf85149);
  static const Color purple = Color(0xFFbc8cff);

  /// Border used on glass cards.
  static const Color glassBorder = Color(0x22ffffff);

  /// Accent gradient (primary -> accent).
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF58a6ff), Color(0xFF3fb950)],
  );

  /// Soft background gradient for large surfaces (splash / panels).
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0d1117), Color(0xFF0a0e14)],
  );

  /// Picks a color for a usage percentage (0..1): green -> orange -> red.
  static Color usageColor(double fraction) {
    if (fraction < 0.6) return accent;
    if (fraction < 0.85) return warning;
    return danger;
  }

  /// Picks a color for a temperature in °C.
  static Color tempColor(double celsius) {
    if (celsius < 60) return accent;
    if (celsius < 80) return warning;
    return danger;
  }
}