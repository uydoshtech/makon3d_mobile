import 'package:flutter_test/flutter_test.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/models/room_type.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

void main() {
  group('MakonProject.migrateScanMode', () {
    test('defaults legacy whole-property projects to entireHousing', () {
      final mode = MakonProject.migrateScanMode(
        entireHousingScan: const HousingScan(id: 'h1'),
        rooms: const [],
      );
      expect(mode, ScanMode.entireHousing);
    });

    test('migrates multiple independent room scans to roomByRoom', () {
      final rooms = [
        ProjectRoom(
          id: 'r1',
          roomType: RoomType.kitchen,
          createdAt: DateTime(2026, 1, 1),
          scan: const HousingScan(id: 's1', localUsdzPath: '/a.usdz'),
        ),
        ProjectRoom(
          id: 'r2',
          roomType: RoomType.bedroom,
          createdAt: DateTime(2026, 1, 2),
          scan: const HousingScan(id: 's2', localUsdzPath: '/b.usdz'),
        ),
      ];
      expect(
        MakonProject.migrateScanMode(rooms: rooms),
        ScanMode.roomByRoom,
      );
    });

    test('fromJson without scanMode preserves room data and migrates', () {
      final json = <String, dynamic>{
        'id': 'p1',
        'name': 'Legacy',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'rooms': [
          {
            'id': 'r1',
            'roomType': 'kitchen',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'scan': {
              'id': 's1',
              'localUsdzPath': '/a.usdz',
            },
          },
          {
            'id': 'r2',
            'roomType': 'bedroom',
            'createdAt': '2026-01-02T00:00:00.000Z',
            'scan': {
              'id': 's2',
              'usdzUrl': 'https://example.com/b.usdz',
            },
          },
        ],
      };
      final project = MakonProject.fromJson(json);
      expect(project.scanMode, ScanMode.roomByRoom);
      expect(project.rooms.length, 2);
      expect(project.rooms.every((r) => r.isScanned), isTrue);
    });
  });

  group('Makon ScanRouting', () {
    test('new Makon project starts at mode selection', () {
      expect(
        ScanRouting.initialDestination(product: ProductContext.makon3D),
        ScanDestination.scanModeSelection,
      );
    });

    test('existing projects open the correct dashboard destination', () {
      expect(
        ScanRouting.initialDestination(
          product: ProductContext.makon3D,
          projectScanMode: ScanMode.entireHousing,
          hasExistingProject: true,
        ),
        ScanDestination.projectDashboard,
      );
      expect(
        ScanRouting.initialDestination(
          product: ProductContext.makon3D,
          projectScanMode: ScanMode.roomByRoom,
          hasExistingProject: true,
        ),
        ScanDestination.roomList,
      );
    });
  });
}
