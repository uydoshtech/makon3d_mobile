import 'package:flutter_test/flutter_test.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/services/makon_project_database.dart';

void main() {
  sqfliteFfiInit();

  late MakonProjectDatabase database;

  setUp(() {
    database = MakonProjectDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() => database.close());

  MakonProject project(String id, {String name = 'Project'}) => MakonProject(
    id: id,
    name: name,
    scanMode: ScanMode.roomByRoom,
    createdAt: DateTime.utc(2026, 8, 3),
  );

  test('stores projects independently for each account', () async {
    await database.replaceProjects(275, [project('artur')]);
    await database.replaceProjects(999, [project('other')]);

    expect((await database.loadProjects(275)).map((value) => value.id), [
      'artur',
    ]);
    expect((await database.loadProjects(999)).map((value) => value.id), [
      'other',
    ]);
  });

  test('replacement is atomic and does not affect another account', () async {
    await database.replaceProjects(275, [project('old')]);
    await database.replaceProjects(999, [project('other')]);
    await database.replaceProjects(275, [project('new-a'), project('new-b')]);

    expect(
      (await database.loadProjects(275)).map((value) => value.id).toSet(),
      {'new-a', 'new-b'},
    );
    expect((await database.loadProjects(999)).map((value) => value.id), [
      'other',
    ]);
  });

  test('upsert and delete persist complete project JSON', () async {
    await database.upsertProject(275, project('one'));
    await database.upsertProject(275, project('one', name: 'Renamed'));

    final loaded = await database.loadProjects(275);
    expect(loaded, hasLength(1));
    expect(loaded.single.name, 'Renamed');

    await database.deleteProject(275, 'one');
    expect(await database.loadProjects(275), isEmpty);
  });
}
