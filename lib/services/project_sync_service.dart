import "package:dio/dio.dart";
import "package:flutter/foundation.dart";

import "package:makon3d_mobile/models/makon_project.dart";
import "package:makon3d_mobile/services/auth/session_manager.dart";
import "package:makon3d_mobile/services/device_identity.dart";
import "package:makon3d_mobile/services/scan_upload_service.dart";

/// Best-effort backup/restore of the local project store against the backend
/// (`/makon3d/projects`), authenticated by the signed-in user session.
///
/// Every local change is pushed; a fresh install pulls the remote set back
/// (see [MakonProjectStore]). All methods swallow errors: sync must never
/// break local project management, and a failed push self-heals on the next
/// app start when the store re-pushes everything.
class ProjectSyncService {
  ProjectSyncService._();

  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: ScanUploadService.basePath,
            connectTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await SessionManager.getToken();
              if (token != null && token.isNotEmpty) {
                options.headers["Authorization"] = "Bearer $token";
              }
              handler.next(options);
            },
          ),
        );

  /// Claims anonymous device backups created before account-scoped project
  /// sync. The server makes this idempotent for the current account.
  static Future<void> claimDeviceProjects() async {
    try {
      final deviceId = await DeviceIdentity.get();
      await _dio.post<void>(
        "/makon3d/projects/claim-device",
        data: <String, dynamic>{"device_id": deviceId},
      );
    } catch (e) {
      debugPrint("ProjectSyncService device claim failed: $e");
      rethrow;
    }
  }

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
      await _dio.put<void>(
        "/makon3d/projects/${Uri.encodeComponent(projectId)}",
        data: <String, dynamic>{
          "device_id": deviceId,
          "data": <String, dynamic>{
            "id": projectId,
            "_deleted": true,
            "updatedAt": DateTime.now().toUtc().toIso8601String(),
          },
        },
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

  /// Remote backups for the signed-in user (empty on any failure). Local file paths
  /// are stripped: they point into the previous install's sandbox, and a
  /// never-uploaded scan is unrecoverable anyway — better to show the room as
  /// not scanned than to reference a dead file.
  static Future<RemoteProjectSnapshot> fetchRemoteProjects() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        "/makon3d/projects",
      );
      final raw = response.data?["projects"];
      if (raw is! List) return const RemoteProjectSnapshot();
      final projects = <MakonProject>[];
      final deletedAt = <String, DateTime>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final data = item["data"];
        if (data is! Map) continue;
        try {
          final json = Map<String, dynamic>.from(data);
          if (json["_deleted"] == true) {
            final id = (item["projectId"] ?? json["id"])?.toString() ?? "";
            final timestamp = DateTime.tryParse(
              (json["updatedAt"] ?? item["updatedAt"])?.toString() ?? "",
            );
            if (id.isNotEmpty && timestamp != null) deletedAt[id] = timestamp;
            continue;
          }
          // Legacy backups did not carry a client mutation timestamp. The
          // backend row timestamp is the best available ordering for them.
          json.putIfAbsent("updatedAt", () => item["updatedAt"]);
          _stripLocalPaths(json);
          final project = MakonProject.fromJson(json);
          if (project.id.isNotEmpty) projects.add(project);
        } catch (e) {
          debugPrint("ProjectSyncService skipped bad backup: $e");
        }
      }
      return RemoteProjectSnapshot(projects: projects, deletedAt: deletedAt);
    } catch (e) {
      debugPrint("ProjectSyncService fetch failed: $e");
      return const RemoteProjectSnapshot();
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

class RemoteProjectSnapshot {
  const RemoteProjectSnapshot({
    this.projects = const [],
    this.deletedAt = const {},
  });

  final List<MakonProject> projects;
  final Map<String, DateTime> deletedAt;
}
