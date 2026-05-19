import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mappy/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedProject(String id) async {
    await db.projectDao.insert(Project(
      id: id,
      name: 'Test Project $id',
      createdAt: DateTime(2026, 5, 19, 9),
    ));
  }

  test('insert + watchActiveForProject returns the observation', () async {
    await seedProject('p1');
    final now = DateTime(2026, 5, 19, 10);
    await db.observationDao.insert(Observation(
      id: 'o1',
      projectId: 'p1',
      description: 'agate vein',
      lat: -29.5,
      lon: -53.5,
      altitude: 320,
      accuracy: 5,
      manualPlacement: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    ));
    final list = await db.observationDao.activeForProject('p1');
    expect(list, hasLength(1));
    expect(list.first.description, 'agate vein');
  });

  test('soft-delete hides observation from active stream', () async {
    await seedProject('p1');
    final now = DateTime(2026, 5, 19, 10);
    await db.observationDao.insert(Observation(
      id: 'o1',
      projectId: 'p1',
      description: '',
      lat: 0,
      lon: 0,
      altitude: null,
      accuracy: null,
      manualPlacement: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    ));
    await db.observationDao.softDelete('o1', now);
    final active = await db.observationDao.activeForProject('p1');
    expect(active, isEmpty);
  });

  test('search matches case-insensitively', () async {
    await seedProject('p1');
    final now = DateTime(2026, 5, 19, 10);
    for (final desc in ['Agate vein', 'basalt host rock', 'CHALCEDONY nodule']) {
      await db.observationDao.insert(Observation(
        id: desc,
        projectId: 'p1',
        description: desc,
        lat: 0,
        lon: 0,
        altitude: null,
        accuracy: null,
        manualPlacement: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      ));
    }
    final results = await db.observationDao.watchSearch('p1', 'chal').first;
    expect(results.map((o) => o.description),
        containsAll(['CHALCEDONY nodule']));
  });

  test('restore removes deletedAt', () async {
    await seedProject('p1');
    final now = DateTime(2026, 5, 19, 10);
    await db.observationDao.insert(Observation(
      id: 'o1',
      projectId: 'p1',
      description: 'x',
      lat: 0,
      lon: 0,
      altitude: null,
      accuracy: null,
      manualPlacement: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    ));
    await db.observationDao.softDelete('o1', now);
    await db.observationDao.restore('o1', now);
    final list = await db.observationDao.activeForProject('p1');
    expect(list, hasLength(1));
  });
}
