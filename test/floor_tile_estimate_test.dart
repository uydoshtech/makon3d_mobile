import 'package:flutter_test/flutter_test.dart';
import 'package:makon3d_mobile/services/floor_tile_estimate.dart';

void main() {
  group('FloorTileEstimator.resolveFloorAreaM2', () {
    test('prefers polygon floor area', () {
      expect(
        FloorTileEstimator.resolveFloorAreaM2(
          floorAreaM2: 11.2,
          floorLongM: 5.5,
          floorShortM: 4.1,
        ),
        11.2,
      );
    });

    test('falls back to long × short', () {
      expect(
        FloorTileEstimator.resolveFloorAreaM2(
          floorLongM: 5,
          floorShortM: 4,
        ),
        20,
      );
    });

    test('returns null when nothing usable', () {
      expect(FloorTileEstimator.resolveFloorAreaM2(), isNull);
    });
  });

  group('FloorTileEstimator.resolveWallAreaM2', () {
    test('perimeter × height', () {
      expect(
        FloorTileEstimator.resolveWallAreaM2(
          floorLongM: 5,
          floorShortM: 4,
          heightM: 2.5,
        ),
        // 2 × (5 + 4) × 2.5
        45,
      );
    });

    test('returns null without height', () {
      expect(
        FloorTileEstimator.resolveWallAreaM2(
          floorLongM: 5,
          floorShortM: 4,
        ),
        isNull,
      );
    });

    test('returns null for non-positive dimensions', () {
      expect(
        FloorTileEstimator.resolveWallAreaM2(
          floorLongM: 5,
          floorShortM: 0,
          heightM: 2.5,
        ),
        isNull,
      );
    });
  });

  group('FloorTileEstimator.estimate', () {
    test('40×40 cm tiles on 10 m² with 10% waste', () {
      final result = FloorTileEstimator.estimate(
        floorAreaM2: 10,
        widthCm: 40,
        heightCm: 40,
        wastePercent: 10,
      )!;
      // effective 11 m² / 0.16 = 68.75 → 69
      expect(result.tileCount, 69);
      expect(result.tileAreaM2, closeTo(0.16, 1e-9));
      expect(result.buyAreaM2, closeTo(69 * 0.16, 1e-9));
    });

    test('rectangular 40×50 cm tiles', () {
      final result = FloorTileEstimator.estimate(
        floorAreaM2: 10,
        widthCm: 40,
        heightCm: 50,
        wastePercent: 0,
      )!;
      // 10 / 0.20 = 50
      expect(result.tileCount, 50);
    });

    test('ceil rounds up partial tiles', () {
      final result = FloorTileEstimator.estimate(
        floorAreaM2: 1,
        widthCm: 60,
        heightCm: 60,
        wastePercent: 0,
      )!;
      // 1 / 0.36 ≈ 2.78 → 3
      expect(result.tileCount, 3);
    });

    test('rejects non-positive inputs', () {
      expect(
        FloorTileEstimator.estimate(
          floorAreaM2: 0,
          widthCm: 40,
          heightCm: 40,
          wastePercent: 10,
        ),
        isNull,
      );
    });
  });
}
