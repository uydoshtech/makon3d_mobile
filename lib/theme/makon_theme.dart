import "package:flutter/material.dart";

import "package:makon3d_mobile/theme/makon_colors.dart";

/// Material 3 theme seeded from the Makon3D logo teal/slate palette.
ThemeData buildMakonTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: MakonColors.teal,
    brightness: Brightness.light,
  );

  final colorScheme = base.copyWith(
    primary: MakonColors.teal,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFD2F1F2),
    onPrimaryContainer: MakonColors.slate,
    secondary: MakonColors.slateElevated,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFDCE4E9),
    onSecondaryContainer: MakonColors.slate,
    tertiary: MakonColors.tealBright,
    surface: MakonColors.surface,
    onSurface: MakonColors.slate,
    onSurfaceVariant: MakonColors.slateMuted,
    outline: MakonColors.slateElevated.withValues(alpha: 0.35),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: MakonColors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: MakonColors.surface,
      foregroundColor: MakonColors.slate,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: MakonColors.teal,
      foregroundColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MakonColors.teal,
        foregroundColor: Colors.white,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MakonColors.teal,
    ),
  );
}
