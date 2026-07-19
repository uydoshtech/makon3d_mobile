import "package:flutter/material.dart";

/// Brand colors from the Makon3D logo lockup.
abstract final class MakonColors {
  /// Splash / deep brand black.
  static const Color black = Color(0xFF000000);

  /// Cube top face + "3D" wordmark.
  static const Color teal = Color(0xFF28A5AC);

  /// Brighter teal highlight (derived from logo accent).
  static const Color tealBright = Color(0xFF34C8CC);

  /// Cube left face / primary slate.
  static const Color slate = Color(0xFF1E2F3D);

  /// Cube right face / elevated slate.
  static const Color slateElevated = Color(0xFF273C4A);

  /// "Makon" wordmark slate.
  static const Color slateMuted = Color(0xFF2C3E50);

  /// Light chrome on dark surfaces (nav labels, etc.).
  static const Color onDark = Color(0xFFF2F7F8);

  /// Soft cool surface for light UI.
  static const Color surface = Color(0xFFF3F7F8);
}
