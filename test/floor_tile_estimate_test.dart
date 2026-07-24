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

  group('FloorTileEstimator plinth', () {
    test('perimeter is 2 × (long + short)', () {
      expect(
        FloorTileEstimator.resolvePerimeterM(floorLongM: 5, floorShortM: 4),
        18,
      );
    });

    test('returns null without both dims', () {
      expect(FloorTileEstimator.resolvePerimeterM(floorLongM: 5), isNull);
    });

    test('strip count ceils at 2.5 m per strip', () {
      // 18 / 2.5 = 7.2 → 8
      expect(FloorTileEstimator.plinthStripCount(18), 8);
    });
  });

  group('FloorTileEstimator.estimateWallpaper', () {
    test('standard roll on 18 m perimeter, 2.5 m walls', () {
      final result = FloorTileEstimator.estimateWallpaper(
        perimeterM: 18,
        wallHeightM: 2.5,
        rollWidthM: 0.53,
        rollLengthM: 10.05,
      )!;
      // strips: ceil(18 / 0.53) = 34; per roll: floor(10.05 / 2.5) = 4;
      // rolls: ceil(34 / 4) = 9
      expect(result.stripsNeeded, 34);
      expect(result.stripsPerRoll, 4);
      expect(result.rollCount, 9);
      expect(result.stripLengthM, 2.5);
    });

    test('pattern repeat lengthens each strip', () {
      final result = FloorTileEstimator.estimateWallpaper(
        perimeterM: 18,
        wallHeightM: 2.5,
        rollWidthM: 0.53,
        rollLengthM: 10.05,
        repeatCm: 64,
      )!;
      // strip 3.14 m → floor(10.05 / 3.14) = 3 per roll → ceil(34 / 3) = 12
      expect(result.stripLengthM, closeTo(3.14, 1e-9));
      expect(result.stripsPerRoll, 3);
      expect(result.rollCount, 12);
    });

    test('falls back to linear meters when roll is shorter than one strip',
        () {
      final result = FloorTileEstimator.estimateWallpaper(
        perimeterM: 10,
        wallHeightM: 12,
        rollWidthM: 1,
        rollLengthM: 10,
      )!;
      // 10 strips × 12 m = 120 m of paper → 12 rolls of 10 m
      expect(result.stripsPerRoll, 0);
      expect(result.rollCount, 12);
    });

    test('rejects non-positive inputs', () {
      expect(
        FloorTileEstimator.estimateWallpaper(
          perimeterM: 0,
          wallHeightM: 2.5,
          rollWidthM: 0.53,
          rollLengthM: 10.05,
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
