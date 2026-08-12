import 'package:flutter/material.dart';

/// The app's fixed palette. Referenced directly wherever a widget needs one
/// of these exact roles (e.g. the ghost bar), not just wherever Material's
/// default component theming happens to land.
class AppColors {
  AppColors._();

  static const background = Color(0xFF03045E);
  static const surface = Color(0xFF012A4A); // cards, bar tracks
  static const primaryBar = Color(0xFF00B4D8); // your bar, buttons
  static const ghostBar = Color(0xFF2C7DA0); // ghost bar
  static const label = Color(0xFF90E0EF); // labels, secondary text
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primaryBar,
    onPrimary: AppColors.background,
    secondary: AppColors.ghostBar,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: Colors.white,
    onSurfaceVariant: AppColors.label,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryBar,
        foregroundColor: AppColors.background,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryBar,
      foregroundColor: AppColors.background,
    ),
  );

  // Material3's auto-generated type styles put most text on onSurface
  // (white here). Labels and other secondary text get their own tone on
  // top of that so they read as distinct from primary content.
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodySmall: base.textTheme.bodySmall?.copyWith(color: AppColors.label),
      labelLarge: base.textTheme.labelLarge?.copyWith(color: AppColors.label),
      labelMedium: base.textTheme.labelMedium?.copyWith(color: AppColors.label),
      labelSmall: base.textTheme.labelSmall?.copyWith(color: AppColors.label),
    ),
  );
}
