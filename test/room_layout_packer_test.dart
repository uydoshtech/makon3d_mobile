import 'package:flutter_test/flutter_test.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/models/room_type.dart';
import 'package:makon3d_mobile/services/room_layout_packer.dart';

ProjectRoom _room({
  required String id,
  double? longM,
  double? offsetX,
  double? offsetZ,
}) {
  return ProjectRoom(
    id: id,
    roomType: RoomType.bedroom,
    createdAt: DateTime(2026, 1, 1),
    scan: HousingScan(
      id: 's-$id',
      localUsdzPath: '/tmp/$id.usdz',
      floorLongM: longM,
    ),
    layoutOffsetXM: offsetX,
    layoutOffsetZM: offsetZ,
  );
}

void main() {
  group('RoomLayoutPacker.packAlongX', () {
    test('packs rooms along +X with gap using footprint width', () {
      final placements = RoomLayoutPacker.packAlongX(
        [
          _room(id: 'a', longM: 4),
          _room(id: 'b', longM: 3),
        ],
        gapM: 0.5,
      );
      expect(placements.length, 2);
      expect(placements[0].offsetXM, 2.0); // half of 4
      expect(placements[0].offsetZM, 0);
      expect(placements[1].offsetXM, 4 + 0.5 + 1.5); // cursor + half of 3
      expect(placements[1].widthM, 3);
    });

    test('keeps explicit layouts when all rooms have them', () {
      final placements = RoomLayoutPacker.packAlongX([
        _room(id: 'a', longM: 4, offsetX: 10, offsetZ: 2),
        _room(id: 'b', longM: 3, offsetX: -1, offsetZ: 5),
      ]);
      expect(placements[0].offsetXM, 10);
      expect(placements[0].offsetZM, 2);
      expect(placements[1].offsetXM, -1);
      expect(placements[1].offsetZM, 5);
    });

    test('ignores unscanned rooms', () {
      final unscanned = ProjectRoom(
        id: 'empty',
        roomType: RoomType.kitchen,
        createdAt: DateTime(2026, 1, 1),
      );
      final placements = RoomLayoutPacker.packAlongX([
        unscanned,
        _room(id: 'a', longM: 2),
        _room(id: 'b', longM: 2),
      ]);
      expect(placements.map((p) => p.roomId), ['a', 'b']);
    });
  });
}
