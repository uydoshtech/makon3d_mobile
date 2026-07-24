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

  /// Approximate wall area from the footprint bounding box:
  /// perimeter (2 × (long + short)) × ceiling height. Door/window openings
  /// are not subtracted.
  static double? resolveWallAreaM2({
    double? floorLongM,
    double? floorShortM,
    double? heightM,
  }) {
    if (floorLongM == null ||
        floorShortM == null ||
        heightM == null ||
        floorLongM <= 0 ||
        floorShortM <= 0 ||
        heightM <= 0) {
      return null;
    }
    return 2 * (floorLongM + floorShortM) * heightM;
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
