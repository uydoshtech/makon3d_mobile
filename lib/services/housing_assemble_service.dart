import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:room_scan_kit/room_scan_kit.dart';

import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/services/room_layout_packer.dart';
import 'package:makon3d_mobile/services/scan_upload_service.dart';

/// Assembles a room-by-room Makon project into one combined USDZ.
///
/// Failure leaves per-room scans and the project store intact.
class HousingAssembleService {
  HousingAssembleService._();

  /// Merges scanned rooms, persists [MakonProject.mergedStructureLocalPath],
  /// and returns the local USDZ path.
  static Future<String> assembleCombinedUsdz(MakonProject project) async {
    if (!Platform.isIOS) {
      throw StateError('Combined housing assembly requires iOS');
    }

    final scanned = project.rooms.where((r) => r.isScanned).toList();
    if (scanned.length < 2) {
      throw StateError('Need at least two scanned rooms');
    }

    final localPaths = <String, String>{};
    for (final room in scanned) {
      localPaths[room.id] = await _ensureLocalUsdz(room);
    }

    final placements = RoomLayoutPacker.packAlongX(scanned);
    final inputs = <RoomUsdzMergeInput>[
      for (final p in placements)
        RoomUsdzMergeInput(
          path: localPaths[p.roomId]!,
          id: p.roomId,
          offsetX: p.offsetXM,
          offsetZ: p.offsetZM,
          yawDeg: p.yawDeg,
        ),
    ];

    final docs = await getApplicationDocumentsDirectory();
    final outDir = Directory('${docs.path}/makon_combined');
    if (!outDir.existsSync()) {
      await outDir.create(recursive: true);
    }
    final outPath = '${outDir.path}/${project.id}.usdz';

    RoomUsdzMergeResult? result;
    try {
      result = await RoomUsdzMerge.mergeRoomScans(
        rooms: inputs,
        gapM: RoomLayoutPacker.defaultGapM,
        outputPath: outPath,
      );
    } on PlatformException catch (e) {
      throw StateError(e.message ?? 'Merge failed');
    }

    if (result == null || result.path.isEmpty) {
      throw StateError('Merge returned no file');
    }
    final file = File(result.path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError('Combined USDZ is missing or empty');
    }

    // Persist layout + merged path without touching individual room scans.
    final byId = {for (final p in placements) p.roomId: p};
    final updatedRooms = project.rooms.map((room) {
      final placement = byId[room.id];
      if (placement == null) return room;
      return room.copyWith(
        layoutOffsetXM: placement.offsetXM,
        layoutOffsetZM: placement.offsetZM,
        layoutYawDeg: placement.yawDeg,
      );
    }).toList();

    final updated = project.copyWith(
      rooms: updatedRooms,
      mergedStructureLocalPath: result.path,
    );
    await MakonProjectStore.instance.upsert(updated);
    return result.path;
  }

  static Future<String> _ensureLocalUsdz(ProjectRoom room) async {
    final scan = room.scan;
    if (scan == null) {
      throw StateError('Room ${room.id} has no scan');
    }
    final local = scan.localUsdzPath;
    if (local != null &&
        local.isNotEmpty &&
        File(local).existsSync() &&
        File(local).lengthSync() > 0) {
      return local;
    }
    final url = scan.usdzUrl;
    if (url == null || url.isEmpty) {
      throw StateError('Room ${room.id} has no local or remote USDZ');
    }
    final absolute = ScanUploadService.hostedUrl(url);
    final temp = await getTemporaryDirectory();
    final file = File('${temp.path}/makon_assemble_${room.id}.usdz');
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(minutes: 2),
        responseType: ResponseType.bytes,
      ),
    );
    await dio.download(absolute, file.path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError('Downloaded USDZ is empty for room ${room.id}');
    }
    return file.path;
  }
}
