import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/services/auth/auth_state.dart';
import 'package:makon3d_mobile/services/makon_project_database.dart';
import 'package:makon3d_mobile/services/project_sync_service.dart';
import 'package:makon3d_mobile/services/room_scan_bounds_service.dart';
import 'package:makon3d_mobile/services/room_usdz_viewer_service.dart';
import 'package:makon3d_mobile/services/scan_upload_service.dart';

/// Local persistence for Makon projects, partitioned by signed-in account and
/// mirrored to the backend via [ProjectSyncService].
class MakonProjectStore extends ChangeNotifier {
  MakonProjectStore._() {
    AuthState().addListener(_handleAuthChanged);
  }

  static final MakonProjectStore instance = MakonProjectStore._();

  static const _legacyPrefsKey = 'makon_projects_v1';
  static const _legacyMigratedKey = 'makon_projects_migrated_from_scans_v1';

  List<MakonProject> _projects = const [];
  bool _loaded = false;
  bool _backendSyncStarted = false;
  Future<void>? _loadFuture;

  List<MakonProject> get projects => List.unmodifiable(_projects);
  bool get isLoaded => _loaded;

  String get _userKeySuffix {
    final userId = AuthState().userId;
    if (userId == null || userId <= 0) {
      throw StateError('A signed-in user is required for project storage.');
    }
    return userId.toString();
  }

  String get _prefsKey => 'makon_projects_v2_user_$_userKeySuffix';
  String get _migratedKey =>
      'makon_projects_migrated_from_scans_v1_user_$_userKeySuffix';

  Future<void> ensureLoaded() async {
    if (!AuthState().isSignedIn) {
      _setGuestState();
      return;
    }
    if (_loaded) {
      _startBackendSync();
      return;
    }
    final pending = _loadFuture;
    if (pending != null) {
      await pending;
      return;
    }
    final load = _loadProjects();
    _loadFuture = load;
    try {
      await load;
    } finally {
      if (identical(_loadFuture, load)) _loadFuture = null;
    }
  }

  Future<void> _loadProjects() async {
    final userId = _userId;
    _projects = await MakonProjectDatabase.instance.loadProjects(userId);
    if (_projects.isEmpty) {
      _projects = await _importSharedPreferencesProjects(userId);
    }
    if (_projects.isEmpty) {
      // Empty local cache means "restore the account snapshot", never
      // "delete remote projects". Wait before exposing the store to the UI.
      _backendSyncStarted = true;
      await _syncWithBackend();
    }
    _loaded = true;
    notifyListeners();
    _startBackendSync();
  }

  int get _userId {
    final userId = AuthState().userId;
    if (userId == null || userId <= 0) {
      throw StateError('A signed-in user is required for project storage.');
    }
    return userId;
  }

  /// One-time migration from the old account-scoped JSON preferences value.
  /// The source key is removed only after the SQLite transaction succeeds.
  Future<List<MakonProject>> _importSharedPreferencesProjects(
    int userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var sourceKey = _prefsKey;
    var raw = prefs.getString(sourceKey);
    if (raw == null || raw.isEmpty) {
      sourceKey = _legacyPrefsKey;
      raw = prefs.getString(sourceKey);
    }
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final projects = <MakonProject>[];
      for (final item in decoded) {
        if (item is Map) {
          final project = MakonProject.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (project.id.isNotEmpty) projects.add(project);
        }
      }
      await MakonProjectDatabase.instance.replaceProjects(userId, projects);
      await prefs.remove(sourceKey);
      // Remove an empty/stale account value when the device-wide legacy value
      // was the successful migration source.
      if (sourceKey == _legacyPrefsKey) await prefs.remove(_prefsKey);
      return projects;
    } catch (error) {
      debugPrint('MakonProjectStore preferences migration failed: $error');
      return const [];
    }
  }

  Future<bool> get hasCompletedScanMigration async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return true;
    // Preserve a completed legacy migration for the first account that owns
    // the device cache, then move the marker into its account namespace.
    if (prefs.getBool(_legacyMigratedKey) == true) {
      await prefs.setBool(_migratedKey, true);
      await prefs.remove(_legacyMigratedKey);
      return true;
    }
    return false;
  }

  Future<void> markScanMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migratedKey, true);
  }

  MakonProject? getById(String id) {
    for (final p in _projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> upsert(MakonProject project) async {
    await ensureLoaded();
    if (!AuthState().isSignedIn) return;
    project = project.copyWith(updatedAt: DateTime.now().toUtc());
    final next = [..._projects];
    final index = next.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      next[index] = project;
    } else {
      next.insert(0, project);
    }
    _projects = next;
    await _persist();
    notifyListeners();
    unawaited(ProjectSyncService.pushProject(project));
  }

  Future<void> delete(String id) async {
    await ensureLoaded();
    if (!AuthState().isSignedIn) return;
    final project = getById(id);
    _projects = _projects.where((p) => p.id != id).toList();
    await _persist();
    notifyListeners();
    unawaited(ProjectSyncService.deleteProject(id));
    if (project != null) {
      unawaited(_cleanupDeletedProject(project));
    }
  }

  /// Clears model media on every project room / entire-housing scan that still
  /// points at [remoteScanId]. Used when the gallery deletes a scan so project
  /// cards stop trying to load a 404 USDZ while keeping measurements.
  Future<void> detachRemoteScan(int remoteScanId) async {
    if (remoteScanId <= 0) return;
    await ensureLoaded();
    if (!AuthState().isSignedIn) return;
    var changed = false;
    final next = <MakonProject>[];
    for (final project in _projects) {
      var projectChanged = false;
      HousingScan? entire = project.entireHousingScan;
      if (entire?.remoteScanId == remoteScanId) {
        entire = entire!.withoutModelMedia();
        projectChanged = true;
      }
      final rooms = <ProjectRoom>[];
      for (final room in project.rooms) {
        final scan = room.scan;
        if (scan?.remoteScanId == remoteScanId) {
          rooms.add(room.copyWith(scan: scan!.withoutModelMedia()));
          projectChanged = true;
        } else {
          rooms.add(room);
        }
      }
      if (projectChanged) {
        changed = true;
        final updated = project.copyWith(
          entireHousingScan: entire,
          rooms: rooms,
        );
        next.add(updated);
        unawaited(ProjectSyncService.pushProject(updated));
      } else {
        next.add(project);
      }
    }
    if (!changed) return;
    _projects = next;
    await _persist();
    notifyListeners();
  }

  /// Refresh [scan]'s usdz/glb URLs from the backend.
  ///
  /// This method is intentionally non-destructive. A missing or temporarily
  /// incomplete remote row must not erase the last known media references from
  /// the local project and then propagate that loss to the project backup.
  /// Explicit scan/project deletion flows are responsible for detaching media.
  ///
  /// When the remote USDZ URL changes (e.g. RoomPlan → photogrammetry), clears
  /// [HousingScan.localUsdzPath] so the viewer downloads the new remote file
  /// instead of keeping a stale on-device path.
  Future<HousingScan> refreshScanMedia(HousingScan scan) async {
    var enriched = scan;
    final localPath = scan.localUsdzPath?.trim();
    if (scan.objectCounts.isEmpty &&
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      try {
        final localMetrics = await RoomScanBoundsService.computeFromUsdPath(
          localPath,
        );
        if (localMetrics != null && localMetrics.objectCounts.isNotEmpty) {
          enriched = scan.copyWith(
            floorLongM: localMetrics.floorLongM,
            floorShortM: localMetrics.floorShortM,
            heightM: localMetrics.heightM,
            floorAreaM2: localMetrics.floorAreaM2,
            objectCounts: localMetrics.objectCounts,
            worldPlusXBearingDeg: localMetrics.worldPlusXBearingDeg,
          );
        }
      } catch (error) {
        debugPrint('[RoomScan] Could not read local USDZ metadata: $error');
      }
    }

    final remoteId = enriched.remoteScanId;
    if (remoteId == null || remoteId <= 0) return enriched;
    try {
      final remote = await ScanUploadService.getScan(remoteId);
      final usdz = remote.usdzUrl?.trim();
      final glb = remote.glbUrl?.trim();
      if ((usdz == null || usdz.isEmpty) && (glb == null || glb.isEmpty)) {
        return enriched;
      }
      final previousUsdz = enriched.usdzUrl?.trim() ?? '';
      final urlChanged =
          usdz != null && usdz.isNotEmpty && usdz != previousUsdz;
      var updated = enriched.withRemoteMedia(
        remoteScanId: remoteId,
        usdzUrl: usdz,
        glbUrl: glb,
      );
      updated = updated.copyWith(
        floorLongM: remote.floorLongM,
        floorShortM: remote.floorShortM,
        heightM: remote.heightM,
        floorAreaM2: remote.floorAreaM2,
        wallPerimeterM: remote.wallPerimeterM,
        doorwayWidthM: remote.doorwayWidthM,
        doorwayAreaM2: remote.doorwayAreaM2,
        windowAreaM2: remote.windowAreaM2,
        roomTypes: remote.roomTypes.isNotEmpty ? remote.roomTypes : null,
        objectCounts: remote.objectCounts.isNotEmpty
            ? remote.objectCounts
            : null,
        worldPlusXBearingDeg: remote.worldPlusXBearingDeg,
        capturedAt: remote.createdAt,
      );
      final isRoomPlanUsdz =
          usdz != null &&
          Uri.tryParse(usdz)?.path.toLowerCase().endsWith('/room_scan.usdz') ==
              true;
      if (updated.objectCounts.isEmpty && isRoomPlanUsdz) {
        try {
          var localFile = await RoomUsdzViewerService.resolveLocalUsdz(
            updated.localUsdzPath,
            fallbackPathOrUrl: usdz,
          );
          localFile ??= await RoomUsdzViewerService.downloadUsdToCache(
            usdz,
            scanId: remoteId,
          );
          if (localFile != null) {
            final localMetrics = await RoomScanBoundsService.computeFromUsdPath(
              localFile.path,
            );
            if (localMetrics != null && localMetrics.objectCounts.isNotEmpty) {
              updated = updated.copyWith(
                objectCounts: localMetrics.objectCounts,
              );
            }
          }
        } catch (error) {
          debugPrint('[RoomScan] Could not inspect remote USDZ: $error');
        }
      }
      // Prefer the new remote asset over a stale on-device USDZ path.
      if (urlChanged && (updated.localUsdzPath?.isNotEmpty ?? false)) {
        return updated.copyWith(clearLocalUsdzPath: true);
      }
      return updated;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return enriched;
      }
      rethrow;
    }
  }

  /// Persist [updated] in place of [previous] wherever it appears in projects.
  ///
  /// Matches only on the local [HousingScan.id]. Matching by `remoteScanId`
  /// alone used to rewrite every project that shared an upload id (e.g. Баха
  /// and a Stage‑7 placeholder both on scan 26) and clobber measurements.
  Future<void> replaceScanMedia({
    required HousingScan previous,
    required HousingScan updated,
  }) async {
    // Include footprint / wall metrics — a backend backfill can correct
    // floor_area_m2 without changing USDZ/GLB URLs or object counts.
    final same =
        previous.remoteScanId == updated.remoteScanId &&
        previous.usdzUrl == updated.usdzUrl &&
        previous.glbUrl == updated.glbUrl &&
        previous.localUsdzPath == updated.localUsdzPath &&
        previous.floorLongM == updated.floorLongM &&
        previous.floorShortM == updated.floorShortM &&
        previous.heightM == updated.heightM &&
        previous.floorAreaM2 == updated.floorAreaM2 &&
        previous.wallPerimeterM == updated.wallPerimeterM &&
        previous.doorwayWidthM == updated.doorwayWidthM &&
        previous.doorwayAreaM2 == updated.doorwayAreaM2 &&
        previous.windowAreaM2 == updated.windowAreaM2 &&
        listEquals(previous.roomTypes, updated.roomTypes) &&
        mapEquals(previous.objectCounts, updated.objectCounts);
    if (same) return;
    await ensureLoaded();
    if (!AuthState().isSignedIn) return;
    var changed = false;
    final next = <MakonProject>[];
    for (final project in _projects) {
      var projectChanged = false;
      HousingScan? entire = project.entireHousingScan;
      if (entire?.id == previous.id) {
        entire = updated;
        projectChanged = true;
      }
      final rooms = <ProjectRoom>[];
      for (final room in project.rooms) {
        final scan = room.scan;
        if (scan != null && scan.id == previous.id) {
          rooms.add(room.copyWith(scan: updated));
          projectChanged = true;
        } else {
          rooms.add(room);
        }
      }
      if (projectChanged) {
        changed = true;
        final updatedProject = project.copyWith(
          entireHousingScan: entire,
          rooms: rooms,
        );
        next.add(updatedProject);
        unawaited(ProjectSyncService.pushProject(updatedProject));
      } else {
        next.add(project);
      }
    }
    if (!changed) return;
    _projects = next;
    await _persist();
    notifyListeners();
  }

  /// Removes a room and its scan from a project.
  Future<void> deleteRoom({
    required String projectId,
    required String roomId,
  }) async {
    await ensureLoaded();
    if (!AuthState().isSignedIn) return;
    final project = getById(projectId);
    if (project == null) return;
    final roomIndex = project.rooms.indexWhere((room) => room.id == roomId);
    if (roomIndex < 0) return;

    final scan = project.rooms[roomIndex].scan;
    final rooms = project.rooms.where((room) => room.id != roomId).toList();
    await upsert(project.copyWith(rooms: rooms));
    if (scan != null) {
      unawaited(_cleanupDeletedScan(scan));
    }
  }

  /// Creates a room whose scan, server media, and local USDZ are independent
  /// from [roomId]. This prevents deleting or editing one copy from affecting
  /// the other.
  Future<ProjectRoom?> duplicateRoomScan({
    required String projectId,
    required String roomId,
    required String duplicateName,
  }) async {
    await ensureLoaded();
    if (!AuthState().isSignedIn) return null;
    final project = getById(projectId);
    if (project == null) return null;
    final sourceIndex = project.rooms.indexWhere((room) => room.id == roomId);
    if (sourceIndex < 0) return null;
    final sourceRoom = project.rooms[sourceIndex];
    final sourceScan = sourceRoom.scan;
    if (sourceScan == null || !sourceRoom.isScanned) return null;

    final copied = await _duplicateHousingScan(sourceScan);
    final now = DateTime.now();
    final duplicateRoom = ProjectRoom(
      id: _newLocalId(),
      roomType: sourceRoom.roomType,
      createdAt: now,
      name: duplicateName,
      scan: copied.scan,
      layoutOffsetXM: sourceRoom.layoutOffsetXM,
      layoutOffsetZM: sourceRoom.layoutOffsetZM,
      layoutYawDeg: sourceRoom.layoutYawDeg,
      floorTilePrefs: sourceRoom.floorTilePrefs,
      wallpaperPrefs: sourceRoom.wallpaperPrefs,
    );

    final latestProject = getById(projectId);
    final latestSourceIndex = latestProject?.rooms.indexWhere(
      (room) => room.id == roomId,
    );
    if (latestProject == null ||
        latestSourceIndex == null ||
        latestSourceIndex < 0) {
      await copied.discard();
      return null;
    }
    final rooms = [...latestProject.rooms]
      ..insert(latestSourceIndex + 1, duplicateRoom);
    try {
      await upsert(latestProject.copyWith(rooms: rooms));
      return duplicateRoom;
    } catch (_) {
      await copied.discard();
      rethrow;
    }
  }

  /// Creates an independent copy of [projectId], including every room scan.
  /// The duplicate is inserted immediately after the source project. Contractor
  /// listings are not copied — the new project starts unpublished.
  Future<MakonProject?> duplicateProject({
    required String projectId,
    required String duplicateName,
  }) async {
    await ensureLoaded();
    if (!AuthState().isSignedIn) return null;
    final source = getById(projectId);
    if (source == null) return null;

    final copiedScans = <_DuplicatedScan>[];
    try {
      HousingScan? entireHousingScan;
      if (source.entireHousingScan case final entire?) {
        final copied = await _duplicateHousingScan(entire);
        copiedScans.add(copied);
        entireHousingScan = copied.scan;
      }

      final rooms = <ProjectRoom>[];
      for (final room in source.rooms) {
        final scan = room.scan;
        HousingScan? duplicatedScan;
        if (scan != null && room.isScanned) {
          final copied = await _duplicateHousingScan(scan);
          copiedScans.add(copied);
          duplicatedScan = copied.scan;
        }
        rooms.add(
          ProjectRoom(
            id: _newLocalId(),
            roomType: room.roomType,
            createdAt: DateTime.now(),
            name: room.name,
            scan: duplicatedScan,
            layoutOffsetXM: room.layoutOffsetXM,
            layoutOffsetZM: room.layoutOffsetZM,
            layoutYawDeg: room.layoutYawDeg,
            floorTilePrefs: room.floorTilePrefs,
            wallpaperPrefs: room.wallpaperPrefs,
          ),
        );
      }

      final now = DateTime.now();
      final duplicate = MakonProject(
        id: _newProjectId(),
        name: duplicateName,
        scanMode: source.scanMode,
        createdAt: now,
        updatedAt: now.toUtc(),
        address: source.address,
        notes: source.notes,
        entireHousingScan: entireHousingScan,
        rooms: rooms,
        entireHousingFloorTilePrefs: source.entireHousingFloorTilePrefs,
        entireHousingWallpaperPrefs: source.entireHousingWallpaperPrefs,
      );

      final latestIndex = _projects.indexWhere(
        (project) => project.id == projectId,
      );
      if (latestIndex < 0) {
        await _discardDuplicatedScans(copiedScans);
        return null;
      }
      final next = [..._projects]..insert(latestIndex + 1, duplicate);
      _projects = next;
      await _persist();
      notifyListeners();
      unawaited(ProjectSyncService.pushProject(duplicate));
      return duplicate;
    } catch (_) {
      await _discardDuplicatedScans(copiedScans);
      rethrow;
    }
  }

  Future<_DuplicatedScan> _duplicateHousingScan(HousingScan sourceScan) async {
    final localId = _newLocalId();
    File? sourceFile;
    try {
      sourceFile = await RoomUsdzViewerService.resolveLocalUsdz(
        sourceScan.localUsdzPath,
        fallbackPathOrUrl: sourceScan.usdzUrl,
      );
    } catch (_) {
      // A server-side duplicate does not require a local source file.
    }

    ScanUploadResult? upload;
    final remoteId = sourceScan.remoteScanId;
    if (remoteId != null && remoteId > 0) {
      try {
        upload = await ScanUploadService.duplicateScan(remoteId);
      } on DioException catch (error) {
        // Compatibility fallback while older API instances are still rolling
        // out: re-upload the on-device USDZ when it is available.
        final status = error.response?.statusCode;
        if (sourceFile == null ||
            (status != 404 && status != 405 && status != 409)) {
          rethrow;
        }
        upload = await ScanUploadService.uploadScan(
          usdzFilePath: sourceFile.path,
        );
      }
    } else if (sourceFile != null) {
      upload = await ScanUploadService.uploadScan(
        usdzFilePath: sourceFile.path,
      );
    }
    if (upload != null && upload.id <= 0) {
      throw StateError('Duplicate scan upload did not return an id.');
    }
    if (sourceScan.hasModel && upload == null && sourceFile == null) {
      throw StateError('The source scan model is unavailable.');
    }

    String? copiedLocalPath;
    if (sourceFile != null) {
      try {
        final support = await getApplicationSupportDirectory();
        final directory = Directory('${support.path}/MakonixScanCopies');
        await directory.create(recursive: true);
        final copy = await sourceFile.copy('${directory.path}/$localId.usdz');
        copiedLocalPath = copy.path;
      } catch (error) {
        debugPrint('MakonProjectStore local scan copy failed: $error');
      }
    }

    return _DuplicatedScan(
      scan: HousingScan(
        id: localId,
        localUsdzPath: copiedLocalPath,
        remoteScanId: upload?.id,
        usdzUrl: upload?.usdzUrl,
        glbUrl: upload?.glbUrl,
        floorLongM: sourceScan.floorLongM,
        floorShortM: sourceScan.floorShortM,
        heightM: sourceScan.heightM,
        floorAreaM2: sourceScan.floorAreaM2,
        wallPerimeterM: upload?.wallPerimeterM ?? sourceScan.wallPerimeterM,
        doorwayWidthM: upload?.doorwayWidthM ?? sourceScan.doorwayWidthM,
        doorwayAreaM2: upload?.doorwayAreaM2 ?? sourceScan.doorwayAreaM2,
        windowAreaM2: upload?.windowAreaM2 ?? sourceScan.windowAreaM2,
        roomTypes: upload?.roomTypes.isNotEmpty == true
            ? upload!.roomTypes
            : sourceScan.roomTypes,
        objectCounts: upload?.objectCounts.isNotEmpty == true
            ? upload!.objectCounts
            : sourceScan.objectCounts,
        worldPlusXBearingDeg: sourceScan.worldPlusXBearingDeg,
        capturedAt: DateTime.now(),
      ),
      remoteId: upload?.id,
      localPath: copiedLocalPath,
    );
  }

  Future<void> _discardDuplicatedScans(List<_DuplicatedScan> scans) async {
    for (final scan in scans) {
      await scan.discard();
    }
  }

  Future<void> _discardDuplicateMedia(int? remoteId, String? localPath) async {
    if (remoteId != null && remoteId > 0) {
      await ProjectSyncService.deleteRemoteScan(remoteId);
    }
    if (localPath == null || localPath.isEmpty) return;
    try {
      final file = File(localPath);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  static String _newLocalId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List.generate(
      6,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '$timestamp-$suffix';
  }

  static String _newProjectId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List.generate(
      8,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '$timestamp-$suffix';
  }

  /// Best-effort teardown after a delete: removes the project's uploaded
  /// scans from the backend (they'd otherwise linger in the public web
  /// gallery as ungrouped scans) and its local USDZ files from disk.
  Future<void> _cleanupDeletedProject(MakonProject project) async {
    final remoteIds = <int>{};
    final localPaths = <String>{};
    void collect(HousingScan? scan) {
      if (scan == null) return;
      final remoteId = scan.remoteScanId;
      if (remoteId != null && remoteId > 0) remoteIds.add(remoteId);
      final path = scan.localUsdzPath;
      if (path != null && path.isNotEmpty) localPaths.add(path);
    }

    collect(project.entireHousingScan);
    for (final room in project.rooms) {
      collect(room.scan);
    }
    final merged = project.mergedStructureLocalPath;
    if (merged != null && merged.isNotEmpty) localPaths.add(merged);

    for (final scanId in remoteIds) {
      await ProjectSyncService.deleteRemoteScan(scanId);
    }
    for (final path in localPaths) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } catch (e) {
        debugPrint('MakonProjectStore file cleanup failed ($path): $e');
      }
    }
  }

  Future<void> _cleanupDeletedScan(HousingScan scan) async {
    final remoteId = scan.remoteScanId;
    if (remoteId != null && remoteId > 0) {
      await ProjectSyncService.deleteRemoteScan(remoteId);
    }
    final path = scan.localUsdzPath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('MakonProjectStore scan file cleanup failed ($path): $e');
    }
  }

  Future<void> replaceAll(List<MakonProject> projects) async {
    if (!AuthState().isSignedIn) return;
    _projects = List.of(projects);
    _loaded = true;
    await _persist();
    notifyListeners();
    unawaited(ProjectSyncService.pushAll(projects));
  }

  Future<void> _persist() async {
    await MakonProjectDatabase.instance.replaceProjects(_userId, _projects);
  }

  /// One-shot background reconcile with the backend backups:
  /// - legacy device backups are claimed by this account;
  /// - remote projects unknown locally are restored (the reinstall case);
  /// - projects are reconciled by their client mutation timestamp;
  /// - only locally newer projects are pushed back to the backend.
  void _startBackendSync() {
    if (!AuthState().isSignedIn || _backendSyncStarted) return;
    _backendSyncStarted = true;
    unawaited(_syncWithBackend());
  }

  /// Re-run backend reconcile (pull-to-refresh). Safe to call repeatedly.
  Future<void> refreshFromRemote() async {
    if (!AuthState().isSignedIn) return;
    await ensureLoaded();
    await _syncWithBackend();
  }

  Future<void> _syncWithBackend() async {
    if (!AuthState().isSignedIn) return;
    try {
      await ProjectSyncService.claimDeviceProjects();
      if (!AuthState().isSignedIn) return;
      final remoteSnapshot = await ProjectSyncService.fetchRemoteProjects();
      final remote = remoteSnapshot.projects;
      if (!AuthState().isSignedIn) return;
      final localById = {for (final p in _projects) p.id: p};
      final remoteById = {for (final p in remote) p.id: p};
      final allIds = {...localById.keys, ...remoteById.keys};
      final reconciled = <MakonProject>[];
      final toPush = <MakonProject>[];
      for (final id in allIds) {
        final local = localById[id];
        final remoteProject = remoteById[id];
        final deletedAt = remoteSnapshot.deletedAt[id];
        if (deletedAt != null &&
            (local == null || !local.updatedAt.isAfter(deletedAt))) {
          continue;
        }
        if (local == null) {
          reconciled.add(remoteProject!);
        } else if (remoteProject == null) {
          reconciled.add(local);
          toPush.add(local);
        } else if (remoteProject.updatedAt.isAfter(local.updatedAt)) {
          reconciled.add(remoteProject);
        } else if (local.updatedAt.isAfter(remoteProject.updatedAt)) {
          reconciled.add(local);
          toPush.add(local);
        } else {
          // Equal timestamps normally mean identical data. Keep local paths but
          // still heal server-side scan media repairs.
          reconciled.add(_mergeRemoteScanMedia(local, remoteProject));
        }
      }
      reconciled.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final changed = !_sameProjectSnapshots(_projects, reconciled);
      if (changed) {
        _projects = reconciled;
        await _persist();
        notifyListeners();
      }
      await ProjectSyncService.pushAll(toPush);
    } catch (e) {
      debugPrint('MakonProjectStore backend sync failed: $e');
    }
  }

  bool _sameProjectSnapshots(List<MakonProject> a, List<MakonProject> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (jsonEncode(a[i].toJson()) != jsonEncode(b[i].toJson())) return false;
    }
    return true;
  }

  /// Heals local scan media from the remote backup when:
  /// - local has no model but remote does, or
  /// - remote points at a different uploaded scan / USDZ URL (e.g. after an
  ///   ops fix that moves photogrammetry off a shared RoomPlan scan id).
  ///
  /// Without the URL/id check, [pushAll] after sync re-uploads a stale local
  /// pointer and undoes server-side media repairs.
  MakonProject _mergeRemoteScanMedia(MakonProject local, MakonProject remote) {
    var changed = false;

    HousingScan? entire = local.entireHousingScan;
    final remoteEntire = remote.entireHousingScan;
    final mergedEntire = _mergedScanMedia(local: entire, remote: remoteEntire);
    if (mergedEntire != entire) {
      entire = mergedEntire;
      changed = true;
    }

    final remoteRooms = {for (final r in remote.rooms) r.id: r};
    final rooms = <ProjectRoom>[];
    for (final room in local.rooms) {
      final remoteRoom = remoteRooms[room.id];
      final mergedScan = _mergedScanMedia(
        local: room.scan,
        remote: remoteRoom?.scan,
      );
      if (mergedScan != room.scan) {
        rooms.add(room.copyWith(scan: mergedScan));
        changed = true;
      } else {
        rooms.add(room);
      }
    }

    if (!changed) return local;
    return local.copyWith(entireHousingScan: entire, rooms: rooms);
  }

  /// Prefer remote upload pointers when they differ; keep richer local metrics.
  HousingScan? _mergedScanMedia({
    required HousingScan? local,
    required HousingScan? remote,
  }) {
    if (remote == null || !remote.hasModel) return local;
    if (local == null || !local.hasModel) return remote;

    final remoteId = remote.remoteScanId;
    final remoteUsdz = remote.usdzUrl?.trim() ?? '';
    final localId = local.remoteScanId;
    final localUsdz = local.usdzUrl?.trim() ?? '';
    final mediaChanged =
        (remoteId != null && remoteId > 0 && remoteId != localId) ||
        (remoteUsdz.isNotEmpty && remoteUsdz != localUsdz);
    // Heal cross-project contamination (e.g. Stage‑7 placeholder id on Баха)
    // and missing metrics after a shared remoteScanId rewrite.
    final identityContaminated =
        remote.id.isNotEmpty &&
        local.id.isNotEmpty &&
        remote.id != local.id &&
        remoteId != null &&
        remoteId == localId;
    final metricsMissing = !local.hasMeasurements && remote.hasMeasurements;
    if (!mediaChanged && !identityContaminated && !metricsMissing) {
      return local;
    }

    return HousingScan(
      id: identityContaminated ? remote.id : local.id,
      localUsdzPath: mediaChanged ? null : local.localUsdzPath,
      remoteScanId: remoteId ?? localId,
      usdzUrl: remoteUsdz.isNotEmpty ? remoteUsdz : local.usdzUrl,
      glbUrl: remote.glbUrl ?? local.glbUrl,
      floorLongM: local.floorLongM ?? remote.floorLongM,
      floorShortM: local.floorShortM ?? remote.floorShortM,
      heightM: local.heightM ?? remote.heightM,
      floorAreaM2: local.floorAreaM2 ?? remote.floorAreaM2,
      wallPerimeterM: local.wallPerimeterM ?? remote.wallPerimeterM,
      doorwayWidthM: local.doorwayWidthM ?? remote.doorwayWidthM,
      doorwayAreaM2: local.doorwayAreaM2 ?? remote.doorwayAreaM2,
      windowAreaM2: local.windowAreaM2 ?? remote.windowAreaM2,
      roomTypes: local.roomTypes.isNotEmpty
          ? local.roomTypes
          : remote.roomTypes,
      objectCounts: local.objectCounts.isNotEmpty
          ? local.objectCounts
          : remote.objectCounts,
      worldPlusXBearingDeg:
          local.worldPlusXBearingDeg ?? remote.worldPlusXBearingDeg,
      capturedAt: local.capturedAt ?? remote.capturedAt,
    );
  }

  void _handleAuthChanged() {
    if (AuthState().isSignedIn) {
      // Guest mode intentionally never reads local projects. Start a fresh
      // authenticated load once a session becomes available.
      _loaded = false;
      _backendSyncStarted = false;
      unawaited(ensureLoaded());
      return;
    }
    _setGuestState();
  }

  /// Removes projects from memory without deleting the local backup. This
  /// prevents project data from appearing after sign-out or in guest mode.
  void _setGuestState() {
    final didChange = _projects.isNotEmpty || !_loaded || _backendSyncStarted;
    _projects = const [];
    _loaded = true;
    _backendSyncStarted = false;
    if (didChange) notifyListeners();
  }
}

class _DuplicatedScan {
  const _DuplicatedScan({required this.scan, this.remoteId, this.localPath});

  final HousingScan scan;
  final int? remoteId;
  final String? localPath;

  Future<void> discard() {
    return MakonProjectStore.instance._discardDuplicateMedia(
      remoteId,
      localPath,
    );
  }
}
