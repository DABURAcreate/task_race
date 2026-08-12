import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFFB300), // amber
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardTheme: const CardThemeData(
      color: Color(0xFF1E1E1E),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
  );
}