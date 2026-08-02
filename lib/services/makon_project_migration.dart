import 'package:flutter/foundation.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/makon_scan.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/services/scan_upload_service.dart';

/// Migrates legacy flat device scans into Makon projects without deleting data.
///
/// Each existing remote scan becomes its own [ScanMode.entireHousing] project.
class MakonProjectMigration {
  MakonProjectMigration._();

  static Future<void> runIfNeeded() async {
    final store = MakonProjectStore.instance;
    await store.ensureLoaded();
    if (await store.hasCompletedScanMigration) return;

    try {
      // If the user already created projects, just mark migration done.
      if (store.projects.isNotEmpty) {
        await store.markScanMigrationCompleted();
        return;
      }

      final scans = await ScanUploadService.listScansForThisDevice();
      if (scans.isEmpty) {
        await store.markScanMigrationCompleted();
        return;
      }

      final projects = <MakonProject>[];
      for (final scan in scans) {
        projects.add(_projectFromLegacyScan(scan));
      }
      await store.replaceAll(projects);
      await store.markScanMigrationCompleted();
      debugPrint(
        'MakonProjectMigration: imported ${projects.length} legacy scans',
      );
    } catch (e) {
      // Leave migration flag unset so a later launch can retry.
      debugPrint('MakonProjectMigration failed: $e');
    }
  }

  static MakonProject _projectFromLegacyScan(MakonScan scan) {
    final created = scan.createdAt ?? DateTime.now();
    final housing = HousingScan(
      id: 'legacy-${scan.id}',
      remoteScanId: scan.id,
      usdzUrl: scan.usdzUrl,
      glbUrl: scan.glbUrl,
      floorLongM: scan.floorLongM,
      floorShortM: scan.floorShortM,
      heightM: scan.heightM,
      floorAreaM2: scan.floorAreaM2,
      wallPerimeterM: scan.wallPerimeterM,
      doorwayWidthM: scan.doorwayWidthM,
      doorwayAreaM2: scan.doorwayAreaM2,
      windowAreaM2: scan.windowAreaM2,
      roomTypes: scan.roomTypes,
      objectCounts: scan.objectCounts,
      worldPlusXBearingDeg: scan.worldPlusXBearingDeg,
      capturedAt: created,
    );
    return MakonProject(
      id: 'migrated-scan-${scan.id}',
      name: 'Scan ${scan.id}',
      scanMode: ScanMode.entireHousing,
      createdAt: created,
      entireHousingScan: housing,
    );
  }
}
