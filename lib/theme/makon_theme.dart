import "package:flutter/material.dart";

import "package:makon3d_mobile/theme/makon_colors.dart";

/// Material 3 theme in the Makon logo palette: black chrome, yellow accents.
ThemeData buildMakonTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: MakonColors.yellow,
    brightness: Brightness.light,
  );

  final colorScheme = base.copyWith(
    primary: MakonColors.ink,
    onPrimary: MakonColors.yellow,
    primaryContainer: MakonColors.yellowSoft,
    onPrimaryContainer: MakonColors.ink,
    secondary: MakonColors.yellow,
    onSecondary: MakonColors.black,
    secondaryContainer: MakonColors.yellowSoft,
    onSecondaryContainer: MakonColors.ink,
    tertiary: MakonColors.yellowBright,
    onTertiary: MakonColors.black,
    surface: MakonColors.surface,
    onSurface: MakonColors.ink,
    onSurfaceVariant: MakonColors.inkMuted,
    outline: MakonColors.ink.withValues(alpha: 0.3),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: MakonColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: MakonColors.surface,
      foregroundColor: MakonColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: MakonColors.yellow,
      foregroundColor: MakonColors.black,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MakonColors.ink,
        foregroundColor: MakonColors.yellow,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MakonColors.ink,
    ),
  );
}
