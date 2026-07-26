import 'dart:math' as math;

/// Result of a floor-tile quantity estimate.
class FloorTileEstimate {
  const FloorTileEstimate({
    required this.floorAreaM2,
    required this.tileAreaM2,
    required this.wastePercent,
    required this.effectiveAreaM2,
    required this.tileCount,
    required this.buyAreaM2,
    required this.usedBoundingFallback,
  });

  final double floorAreaM2;
  final double tileAreaM2;
  final double wastePercent;
  final double effectiveAreaM2;
  final int tileCount;
  final double buyAreaM2;
  final bool usedBoundingFallback;
}

/// Result of a wallpaper roll estimate (strip-based, not area-based —
/// computing rolls from m² is how people end up one roll short).
class WallpaperEstimate {
  const WallpaperEstimate({
    required this.stripLengthM,
    required this.stripsNeeded,
    required this.stripsPerRoll,
    required this.rollCount,
  });

  final double stripLengthM;
  final int stripsNeeded;

  /// 0 when the roll is shorter than one strip (linear-meters fallback).
  final int stripsPerRoll;
  final int rollCount;
}

/// Pure floor-tile math. Tile sizes are in centimeters.
class FloorTileEstimator {
  const FloorTileEstimator._();

  /// Prefer [floorAreaM2]; if missing, fall back to [floorLongM] × [floorShortM].
  static double? resolveFloorAreaM2({
    double? floorAreaM2,
    double? floorLongM,
    double? floorShortM,
  }) {
    if (floorAreaM2 != null && floorAreaM2 > 0) return floorAreaM2;
    if (floorLongM != null &&
        floorShortM != null &&
        floorLongM > 0 &&
        floorShortM > 0) {
      return floorLongM * floorShortM;
    }
    return null;
  }

  static bool usedBoundingFallback({
    double? floorAreaM2,
    double? floorLongM,
    double? floorShortM,
  }) {
    if (floorAreaM2 != null && floorAreaM2 > 0) return false;
    return floorLongM != null &&
        floorShortM != null &&
        floorLongM > 0 &&
        floorShortM > 0;
  }

  /// Standard skirting-board strip length.
  static const plinthStripLengthM = 2.5;

  /// Approximate footprint perimeter from the OBB dims: 2 × (long + short).
  /// Door openings are not subtracted.
  static double? resolvePerimeterM({double? floorLongM, double? floorShortM}) {
    if (floorLongM == null ||
        floorShortM == null ||
        floorLongM <= 0 ||
        floorShortM <= 0) {
      return null;
    }
    return 2 * (floorLongM + floorShortM);
  }

  /// Whole [plinthStripLengthM] strips needed to cover [perimeterM].
  static int plinthStripCount(double perimeterM) =>
      math.max(1, (perimeterM / plinthStripLengthM).ceil());

  static WallpaperEstimate? estimateWallpaper({
    required double perimeterM,
    required double wallHeightM,
    required double rollWidthM,
    required double rollLengthM,
    double repeatCm = 0,
  }) {
    if (perimeterM <= 0 ||
        wallHeightM <= 0 ||
        rollWidthM <= 0 ||
        rollLengthM <= 0) {
      return null;
    }
    // Each strip is cut to wall height plus one pattern repeat for alignment.
    final stripLengthM = wallHeightM + repeatCm.clamp(0, 500) / 100;
    final stripsNeeded = math.max(1, (perimeterM / rollWidthM).ceil());
    final stripsPerRoll = (rollLengthM / stripLengthM).floor();
    // Roll shorter than one strip (very tall space): fall back to linear
    // meters so the answer stays a usable over-estimate instead of dividing
    // by zero strips.
    final rollCount = stripsPerRoll >= 1
        ? (stripsNeeded / stripsPerRoll).ceil()
        : ((stripsNeeded * stripLengthM) / rollLengthM).ceil();
    return WallpaperEstimate(
      stripLengthM: stripLengthM,
      stripsNeeded: stripsNeeded,
      stripsPerRoll: stripsPerRoll,
      rollCount: math.max(1, rollCount),
    );
  }

  static FloorTileEstimate? estimate({
    required double floorAreaM2,
    required double widthCm,
    required double heightCm,
    required double wastePercent,
    bool usedBoundingFallback = false,
  }) {
    if (floorAreaM2 <= 0 || widthCm <= 0 || heightCm <= 0) return null;
    final waste = wastePercent.clamp(0, 100).toDouble();
    final tileAreaM2 = (widthCm / 100) * (heightCm / 100);
    if (tileAreaM2 <= 0) return null;
    final effectiveAreaM2 = floorAreaM2 * (1 + waste / 100);
    final tileCount = math.max(1, (effectiveAreaM2 / tileAreaM2).ceil());
    return FloorTileEstimate(
      floorAreaM2: floorAreaM2,
      tileAreaM2: tileAreaM2,
      wastePercent: waste,
      effectiveAreaM2: effectiveAreaM2,
      tileCount: tileCount,
      buyAreaM2: tileCount * tileAreaM2,
      usedBoundingFallback: usedBoundingFallback,
    );
  }
}
