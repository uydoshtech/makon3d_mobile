import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:makon3d_mobile/models/makon_project.dart';

/// Local persistence for Makon projects (device-scoped SharedPreferences JSON).
class MakonProjectStore extends ChangeNotifier {
  MakonProjectStore._();

  static final MakonProjectStore instance = MakonProjectStore._();

  static const _prefsKey = 'makon_projects_v1';
  static const _migratedKey = 'makon_projects_migrated_from_scans_v1';

  List<MakonProject> _projects = const [];
  bool _loaded = false;

  List<MakonProject> get projects => List.unmodifiable(_projects);
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _projects = const [];
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
  }

  Future<void> delete(String id) async {
    await ensureLoaded();
    _projects = _projects.where((p) => p.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> replaceAll(List<MakonProject> projects) async {
    _projects = List.of(projects);
    _loaded = true;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(_projects.map((p) => p.toJson()).toList(growable: false));
    await prefs.setString(_prefsKey, encoded);
  }
}
