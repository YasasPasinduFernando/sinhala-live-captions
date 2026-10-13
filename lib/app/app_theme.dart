import 'package:flutter/material.dart';

/// Light, dark, and high-contrast themes with large controls.
ThemeData buildAppTheme({
  required Brightness brightness,
  required bool highContrast,
}) {
  final isDark = brightness == Brightness.dark;
  final seed = isDark ? const Color(0xFF8AB4F8) : const Color(0xFF0D47A1);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    contrastLevel: highContrast ? 1 : 0,
  );
  final surface = highContrast
      ? (isDark ? Colors.black : Colors.white)
      : scheme.surface;
  final onSurface = highContrast
      ? (isDark ? Colors.white : Colors.black)
      : scheme.onSurface;
  final primary = highContrast
      ? (isDark ? Colors.white : Colors.black)
      : scheme.primary;
  final onPrimary = highContrast
      ? (isDark ? Colors.black : Colors.white)
      : scheme.onPrimary;

  final colorScheme = scheme.copyWith(
    surface: surface,
    onSurface: onSurface,
    primary: primary,
    onPrimary: onPrimary,
  );
  final theme = ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surface,
    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(bodyColor: onSurface, displayColor: onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: onSurface.withValues(alpha: 0.35)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        foregroundColor: onSurface,
        side: BorderSide(color: onSurface, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    focusColor: onSurface.withValues(alpha: 0.24),
  );
  return theme;
}
