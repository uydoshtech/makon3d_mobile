import "package:dio/dio.dart";
import "package:flutter/foundation.dart";

import "package:makon3d_mobile/models/makon_project.dart";
import "package:makon3d_mobile/services/device_identity.dart";
import "package:makon3d_mobile/services/scan_upload_service.dart";

/// Best-effort backup/restore of the local project store against the backend
/// (`/makon3d/projects`), keyed by the Keychain-persisted device id — so
/// deleting and reinstalling the app no longer loses projects.
///
/// Every local change is pushed; a fresh install pulls the remote set back
/// (see [MakonProjectStore]). All methods swallow errors: sync must never
/// break local project management, and a failed push self-heals on the next
/// app start when the store re-pushes everything.
class ProjectSyncService {
  ProjectSyncService._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ScanUploadService.basePath,
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  static Future<void> pushProject(MakonProject project) async {
    if (project.id.isEmpty) return;
    try {
      final deviceId = await DeviceIdentity.get();
      await _dio.put<void>(
        "/makon3d/projects/${Uri.encodeComponent(project.id)}",
        data: <String, dynamic>{
          "device_id": deviceId,
          "data": project.toJson(),
        },
      );
    } catch (e) {
      debugPrint("ProjectSyncService push failed (${project.id}): $e");
    }
  }

  static Future<void> pushAll(Iterable<MakonProject> projects) async {
    for (final project in projects) {
      await pushProject(project);
    }
  }

  static Future<void> deleteProject(String projectId) async {
    if (projectId.isEmpty) return;
    try {
      final deviceId = await DeviceIdentity.get();
      await _dio.delete<void>(
        "/makon3d/projects/${Uri.encodeComponent(projectId)}",
        queryParameters: <String, dynamic>{"device_id": deviceId},
      );
    } catch (e) {
      debugPrint("ProjectSyncService delete failed ($projectId): $e");
    }
  }

  /// Deletes an uploaded scan from the backend gallery — called when its
  /// project is deleted so the scan doesn't linger in the public web feed.
  static Future<void> deleteRemoteScan(int scanId) async {
    if (scanId <= 0) return;
    try {
      await _dio.delete<void>("/makon3d/scans/$scanId");
    } catch (e) {
      debugPrint("ProjectSyncService scan delete failed ($scanId): $e");
    }
  }

  /// Remote backups for this device (empty on any failure). Local file paths
  /// are stripped: they point into the previous install's sandbox, and a
  /// never-uploaded scan is unrecoverable anyway — better to show the room as
  /// not scanned than to reference a dead file.
  static Future<List<MakonProject>> fetchRemoteProjects() async {
    try {
      final deviceId = await DeviceIdentity.get();
      final response = await _dio.get<Map<String, dynamic>>(
        "/makon3d/projects",
        queryParameters: <String, dynamic>{"device_id": deviceId},
      );
      final raw = response.data?["projects"];
      if (raw is! List) return const [];
      final projects = <MakonProject>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final data = item["data"];
        if (data is! Map) continue;
        try {
          final json = Map<String, dynamic>.from(data);
          _stripLocalPaths(json);
          final project = MakonProject.fromJson(json);
          if (project.id.isNotEmpty) projects.add(project);
        } catch (e) {
          debugPrint("ProjectSyncService skipped bad backup: $e");
        }
      }
      return projects;
    } catch (e) {
      debugPrint("ProjectSyncService fetch failed: $e");
      return const [];
    }
  }

  static void _stripLocalPaths(Map<String, dynamic> projectJson) {
    projectJson.remove("mergedStructureLocalPath");
    final entire = projectJson["entireHousingScan"];
    if (entire is Map) entire.remove("localUsdzPath");
    final rooms = projectJson["rooms"];
    if (rooms is List) {
      for (final room in rooms) {
        if (room is! Map) continue;
        final scan = room["scan"];
        if (scan is Map) scan.remove("localUsdzPath");
      }
    }
  }
}
