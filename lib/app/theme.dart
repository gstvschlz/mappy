import 'package:flutter/material.dart';

ThemeData mappyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6B4F2A), // warm geology brown
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
