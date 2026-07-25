import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        surface: AppColors.background,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.danger,
        onSurface: AppColors.onBackground,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      dividerColor: AppColors.surfaceVariant,
      iconTheme: const IconThemeData(color: AppColors.onBackground),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.onBackground,
        displayColor: AppColors.onBackground,
      ).copyWith(
        headlineMedium: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.5),
        titleLarge: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600),
        labelLarge: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.4),
        bodySmall: const TextStyle(color: AppColors.muted),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceVariant,
        thumbColor: AppColors.primary,
        overlayColor: Color(0x3358a6ff),
      ),
    );
  }
}