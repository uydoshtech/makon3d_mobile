import "package:flutter/material.dart";

/// Brand colors from the Makon logo (black mark on yellow field).
abstract final class MakonColors {
  /// Brand mark / primary chrome black.
  static const Color black = Color(0xFF000000);

  /// Splash / app-icon field + primary accent (Makon yellow).
  static const Color yellow = Color(0xFFFFCC00);

  /// Brighter yellow highlight (active/pressed accents).
  static const Color yellowBright = Color(0xFFFFDB4D);

  /// Pale yellow for tinted containers and chips.
  static const Color yellowSoft = Color(0xFFFFF3C2);

  /// Primary text / dark surfaces (softened brand black).
  static const Color ink = Color(0xFF161616);

  /// Elevated dark chrome (nav bar, dark sheets).
  static const Color inkElevated = Color(0xFF242424);

  /// Secondary text.
  static const Color inkMuted = Color(0xFF5C5C5C);

  /// Light chrome on dark surfaces (nav labels, etc.).
  static const Color onDark = Color(0xFFFAF7EF);

  /// Soft warm surface for light UI.
  static const Color surface = Color(0xFFFAF8F3);
}
