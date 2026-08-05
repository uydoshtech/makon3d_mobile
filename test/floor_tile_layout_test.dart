import 'package:flutter_test/flutter_test.dart';
import 'package:makon3d_mobile/services/floor_tile_layout.dart';

void main() {
  group('FloorTileLayout', () {
    test('builds a serpentine numbered sequence', () {
      final layout = FloorTileLayout(
        roomWidthM: 2,
        roomLengthM: 1.5,
        tileWidthCm: 50,
        tileLengthCm: 50,
      );

      expect(layout.columns, 4);
      expect(layout.rows, 3);
      expect(layout.positionCount, 12);
      expect(
        [
          for (var column = 0; column < 4; column++)
            layout.tileNumberAt(0, column),
        ],
        [1, 2, 3, 4],
      );
      expect(
        [
          for (var column = 0; column < 4; column++)
            layout.tileNumberAt(1, column),
        ],
        [8, 7, 6, 5],
      );
      expect(
        [
          for (var column = 0; column < 4; column++)
            layout.tileNumberAt(2, column),
        ],
        [9, 10, 11, 12],
      );
    });

    test('marks partial tiles on the final row and column', () {
      final layout = FloorTileLayout(
        roomWidthM: 2.1,
        roomLengthM: 1.1,
        tileWidthCm: 50,
        tileLengthCm: 50,
      );

      expect(layout.columns, 5);
      expect(layout.rows, 3);
      expect(layout.hasCutColumn, isTrue);
      expect(layout.hasCutRow, isTrue);
      expect(layout.isCutPosition(0, 4), isTrue);
      expect(layout.isCutPosition(2, 0), isTrue);
      expect(layout.isCutPosition(1, 1), isFalse);
    });

    test('does not mark cuts when dimensions divide evenly', () {
      final layout = FloorTileLayout(
        roomWidthM: 2,
        roomLengthM: 1.5,
        tileWidthCm: 50,
        tileLengthCm: 50,
      );

      expect(layout.hasCutColumn, isFalse);
      expect(layout.hasCutRow, isFalse);
    });
  });
}
