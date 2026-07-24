import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/services/project_sync_service.dart';

/// Local persistence for Makon projects (device-scoped SharedPreferences
/// JSON), mirrored to the backend via [ProjectSyncService] so projects
/// survive app deletion + reinstall: every change is pushed best-effort, and
/// the first load after a (re)install pulls this device's backups back.
class MakonProjectStore extends ChangeNotifier {
  MakonProjectStore._();

  static final MakonProjectStore instance = MakonProjectStore._();

  static const _prefsKey = 'makon_projects_v1';
  static const _migratedKey = 'makon_projects_migrated_from_scans_v1';

  List<MakonProject> _projects = const [];
  bool _loaded = false;
  bool _backendSyncStarted = false;

  List<MakonProject> get projects => List.unmodifiable(_projects);
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      _startBackendSync();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _projects = const [];
      _loaded = true;
      notifyListeners();
      _startBackendSync();
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
            list.add(
              MakonProject.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      _projects = list;
    } catch (e) {
      debugPrint('MakonProjectStore load failed: $e');
      _projects = const [];
    }
    _loaded = true;
    notifyListeners();
    _startBackendSync();
  }

  Future<bool> get hasCompletedScanMigration async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migratedKey) ?? false;
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
    _projects = _projects.where((p) => p.id != id).toList();
    await _persist();
    notifyListeners();
    unawaited(ProjectSyncService.deleteProject(id));
  }

  Future<void> replaceAll(List<MakonProject> projects) async {
    _projects = List.of(projects);
    _loaded = true;
    await _persist();
    notifyListeners();
    unawaited(ProjectSyncService.pushAll(projects));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(_projects.map((p) => p.toJson()).toList(growable: false));
    await prefs.setString(_prefsKey, encoded);
  }

  /// One-shot background reconcile with the backend backups:
  /// - remote projects unknown locally are restored (the reinstall case);
  /// - every local project is (re-)pushed, healing failed past pushes.
  /// Local always wins for projects present on both sides — this device is
  /// the only writer of its own backups.
  void _startBackendSync() {
    if (_backendSyncStarted) return;
    _backendSyncStarted = true;
    unawaited(_syncWithBackend());
  }

  Future<void> _syncWithBackend() async {
    try {
      final remote = await ProjectSyncService.fetchRemoteProjects();
      final localIds = _projects.map((p) => p.id).toSet();
      final restored =
          remote.where((p) => !localIds.contains(p.id)).toList(growable: false);
      if (restored.isNotEmpty) {
        final merged = [..._projects, ...restored]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _projects = merged;
        await _persist();
        notifyListeners();
      }
      await ProjectSyncService.pushAll(_projects);
    } catch (e) {
      debugPrint('MakonProjectStore backend sync failed: $e');
    }
  }
}
