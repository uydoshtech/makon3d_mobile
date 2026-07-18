import 'package:makon3d_mobile/models/project_room.dart';

/// Placement of one room in the combined housing layout.
class RoomLayoutPlacement {
  const RoomLayoutPlacement({
    required this.roomId,
    required this.offsetXM,
    required this.offsetZM,
    this.yawDeg = 0,
    required this.widthM,
  });

  final String roomId;
  final double offsetXM;
  final double offsetZM;
  final double yawDeg;
  final double widthM;
}

/// Pure layout helper: pack scanned rooms along +X with a gap.
///
/// Uses stored footprint metrics when available; falls back to 4 m width.
class RoomLayoutPacker {
  RoomLayoutPacker._();

  static const double defaultGapM = 0.5;
  static const double fallbackWidthM = 4.0;

  /// Returns placements for [rooms] that have a scan. Preserves explicit layout
  /// when every scanned room already has [ProjectRoom.hasExplicitLayout].
  static List<RoomLayoutPlacement> packAlongX(
    List<ProjectRoom> rooms, {
    double gapM = defaultGapM,
  }) {
    final scanned = rooms.where((r) => r.isScanned).toList();
    if (scanned.isEmpty) return const [];

    if (scanned.every((r) => r.hasExplicitLayout)) {
      return [
        for (final r in scanned)
          RoomLayoutPlacement(
            roomId: r.id,
            offsetXM: r.layoutOffsetXM!,
            offsetZM: r.layoutOffsetZM!,
            yawDeg: r.layoutYawDeg ?? 0,
            widthM: _widthOf(r),
          ),
      ];
    }

    var cursorX = 0.0;
    final gap = gapM < 0 ? 0.0 : gapM;
    final out = <RoomLayoutPlacement>[];
    for (final room in scanned) {
      final width = _widthOf(room);
      final offsetX = cursorX + width * 0.5;
      out.add(
        RoomLayoutPlacement(
          roomId: room.id,
          offsetXM: offsetX,
          offsetZM: 0,
          yawDeg: room.layoutYawDeg ?? 0,
          widthM: width,
        ),
      );
      cursorX += width + gap;
    }
    return out;
  }

  static double _widthOf(ProjectRoom room) {
    final long = room.scan?.floorLongM;
    final short = room.scan?.floorShortM;
    if (long != null && long > 0.2) return long;
    if (short != null && short > 0.2) return short;
    return fallbackWidthM;
  }
}
