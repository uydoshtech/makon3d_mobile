import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/services/auth/auth_state.dart';
import 'package:makon3d_mobile/services/project_sync_service.dart';
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
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_prefsKey);
    // The former device-wide cache belongs to the first account that claims
    // this device's legacy backups. Move it once, then never expose it to a
    // different account on this device.
    if ((raw == null || raw.isEmpty) &&
        (prefs.getString(_legacyPrefsKey)?.isNotEmpty ?? false)) {
      raw = prefs.getString(_legacyPrefsKey);
      await prefs.setString(_prefsKey, raw!);
      await prefs.remove(_legacyPrefsKey);
    }
    if (raw == null || raw.isEmpty) {
      _projects = const [];
      // A development reinstall (and occasionally a TestFlight/container
      // migration) can start with an empty SharedPreferences domain even
      // though the authenticated account still has its project backups.
      // Restore synchronously before declaring the store loaded; otherwise
      // the Projects screen renders a durable-looking empty state while the
      // recovery request is still running in the background.
      _backendSyncStarted = true;
      await _syncWithBackend();
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      final list = <MakonProject>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(MakonProject.fromJson(item));
          } else if (item is Map) {
            list.add(MakonProject.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      _projects = list;
    } catch (e) {
      debugPrint('MakonProjectStore load failed: $e');
      _projects = const [];
    }
    if (_projects.isEmpty) {
      // An empty/corrupt preferences payload has the same recovery semantics
      // as a missing one. Wait for the account backup before exposing the
      // store, so an app/container migration cannot flash an empty project
      // list and let that state drive follow-up actions.
      _backendSyncStarted = true;
      await _syncWithBackend();
    }
    _loaded = true;
    notifyListeners();
    _startBackendSync();
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
    final remoteId = scan.remoteScanId;
    if (remoteId == null || remoteId <= 0) return scan;
    try {
      final remote = await ScanUploadService.getScan(remoteId);
      final usdz = remote.usdzUrl?.trim();
      final glb = remote.glbUrl?.trim();
      if ((usdz == null || usdz.isEmpty) && (glb == null || glb.isEmpty)) {
        return scan;
      }
      final previousUsdz = scan.usdzUrl?.trim() ?? '';
      final urlChanged =
          usdz != null && usdz.isNotEmpty && usdz != previousUsdz;
      final updated = scan.withRemoteMedia(
        remoteScanId: remoteId,
        usdzUrl: usdz,
        glbUrl: glb,
      );
      // Prefer the new remote asset over a stale on-device USDZ path.
      if (urlChanged && (updated.localUsdzPath?.isNotEmpty ?? false)) {
        return updated.copyWith(clearLocalUsdzPath: true);
      }
      return updated;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return scan;
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
    final same =
        previous.remoteScanId == updated.remoteScanId &&
        previous.usdzUrl == updated.usdzUrl &&
        previous.glbUrl == updated.glbUrl &&
        previous.localUsdzPath == updated.localUsdzPath;
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
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _projects.map((p) => p.toJson()).toList(growable: false),
    );
    await prefs.setString(_prefsKey, encoded);
  }

  /// One-shot background reconcile with the backend backups:
  /// - legacy device backups are claimed by this account;
  /// - remote projects unknown locally are restored (the reinstall case);
  /// - every local project is (re-)pushed, healing failed past pushes.
  /// Local always wins for projects present on both sides — this device is
  /// the only writer of its own backups.
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
      final remote = await ProjectSyncService.fetchRemoteProjects();
      if (!AuthState().isSignedIn) return;
      final localIds = _projects.map((p) => p.id).toSet();
      final restored = remote
          .where((p) => !localIds.contains(p.id))
          .toList(growable: false);
      var changed = false;
      if (restored.isNotEmpty) {
        final merged = [..._projects, ...restored]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _projects = merged;
        changed = true;
      }
      // Local wins for project identity, but adopt remote scan media when this
      // device has an unscanned room/housing and the backup already has a model
      // (e.g. photogrammetry USDZ attached on another device / simulator).
      final byId = {for (final p in remote) p.id: p};
      final healed = <MakonProject>[];
      for (final local in _projects) {
        final remoteProject = byId[local.id];
        if (remoteProject == null) {
          healed.add(local);
          continue;
        }
        final next = _mergeRemoteScanMedia(local, remoteProject);
        if (next != local) changed = true;
        healed.add(next);
      }
      if (changed) {
        _projects = healed;
        await _persist();
        notifyListeners();
      }
      await ProjectSyncService.pushAll(_projects);
    } catch (e) {
      debugPrint('MakonProjectStore backend sync failed: $e');
    }
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
