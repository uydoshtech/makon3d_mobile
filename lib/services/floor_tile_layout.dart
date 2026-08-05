import 'dart:math' as math;

/// Rectangular tile layout derived from the scanned room bounds.
///
/// The scan currently stores an oriented bounding rectangle rather than the
/// exact floor polygon, so this model is intentionally a laying guide rather
/// than a cut-ready construction drawing.
class FloorTileLayout {
  const FloorTileLayout._({
    required this.roomWidthM,
    required this.roomLengthM,
    required this.tileWidthM,
    required this.tileLengthM,
    required this.columns,
    required this.rows,
  });

  factory FloorTileLayout({
    required double roomWidthM,
    required double roomLengthM,
    required double tileWidthCm,
    required double tileLengthCm,
  }) {
    assert(roomWidthM > 0);
    assert(roomLengthM > 0);
    assert(tileWidthCm > 0);
    assert(tileLengthCm > 0);

    final tileWidthM = tileWidthCm / 100;
    final tileLengthM = tileLengthCm / 100;
    return FloorTileLayout._(
      roomWidthM: roomWidthM,
      roomLengthM: roomLengthM,
      tileWidthM: tileWidthM,
      tileLengthM: tileLengthM,
      columns: math.max(1, (roomWidthM / tileWidthM).ceil()),
      rows: math.max(1, (roomLengthM / tileLengthM).ceil()),
    );
  }

  final double roomWidthM;
  final double roomLengthM;
  final double tileWidthM;
  final double tileLengthM;
  final int columns;
  final int rows;

  int get positionCount => columns * rows;

  double get roomAspectRatio => roomWidthM / roomLengthM;

  bool get hasCutColumn =>
      (roomWidthM - (columns - 1) * tileWidthM - tileWidthM).abs() > 0.0001;

  bool get hasCutRow =>
      (roomLengthM - (rows - 1) * tileLengthM - tileLengthM).abs() > 0.0001;

  /// Sequence starts at the top-left corner and snakes through the room.
  int tileNumberAt(int row, int column) {
    assert(row >= 0 && row < rows);
    assert(column >= 0 && column < columns);
    final rowStart = row * columns;
    if (row.isEven) return rowStart + column + 1;
    return rowStart + (columns - column);
  }

  bool isCutPosition(int row, int column) =>
      (hasCutColumn && column == columns - 1) || (hasCutRow && row == rows - 1);
}
