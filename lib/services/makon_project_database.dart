import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:makon3d_mobile/models/makon_project.dart';

/// Transactional on-device cache for account-owned Makon projects.
///
/// PostgreSQL remains authoritative. This database makes projects available
/// immediately/offline and safely queues a complete local snapshot without
/// storing application data in SharedPreferences.
class MakonProjectDatabase {
  MakonProjectDatabase({DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? databaseFactory,
      assert(databasePath == null || databasePath.isNotEmpty);

  static final MakonProjectDatabase instance = MakonProjectDatabase();

  static const _databaseName = 'makon_projects.sqlite3';
  static const _schemaVersion = 1;
  static const _projectsTable = 'projects';

  final DatabaseFactory _factory;
  @visibleForTesting
  final String? databasePath;
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    var path = databasePath;
    if (path == null) {
      final support = await getApplicationSupportDirectory();
      await support.create(recursive: true);
      path = '${support.path}/$_databaseName';
    }
    final opened = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async {
          await db.execute('''
          CREATE TABLE $_projectsTable (
            user_id INTEGER NOT NULL,
            project_id TEXT NOT NULL,
            data_json TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL,
            updated_at_ms INTEGER NOT NULL,
            PRIMARY KEY (user_id, project_id)
          )
        ''');
          await db.execute('''
          CREATE INDEX projects_user_created_idx
          ON $_projectsTable (user_id, created_at_ms DESC)
        ''');
        },
      ),
    );
    _database = opened;
    return opened;
  }

  Future<List<MakonProject>> loadProjects(int userId) async {
    final db = await _db;
    final rows = await db.query(
      _projectsTable,
      columns: const ['data_json'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at_ms DESC',
    );
    final projects = <MakonProject>[];
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row['data_json']! as String);
        if (decoded is Map) {
          final project = MakonProject.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (project.id.isNotEmpty) projects.add(project);
        }
      } catch (error) {
        debugPrint('MakonProjectDatabase skipped corrupt row: $error');
      }
    }
    return projects;
  }

  Future<void> replaceProjects(
    int userId,
    Iterable<MakonProject> projects,
  ) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.delete(
        _projectsTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final project in projects) {
        await _insert(transaction, userId, project);
      }
    });
  }

  Future<void> upsertProject(int userId, MakonProject project) async {
    final db = await _db;
    await _insert(db, userId, project);
  }

  Future<void> deleteProject(int userId, String projectId) async {
    final db = await _db;
    await db.delete(
      _projectsTable,
      where: 'user_id = ? AND project_id = ?',
      whereArgs: [userId, projectId],
    );
  }

  @visibleForTesting
  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }

  Future<void> _insert(
    DatabaseExecutor db,
    int userId,
    MakonProject project,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(_projectsTable, <String, Object>{
      'user_id': userId,
      'project_id': project.id,
      'data_json': jsonEncode(project.toJson()),
      'created_at_ms': project.createdAt.millisecondsSinceEpoch,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
