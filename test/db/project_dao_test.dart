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

  test('insert and getAll', () async {
    await db.projectDao.insert(Project(
      id: 'a',
      name: 'Alpha',
      createdAt: DateTime(2026, 5, 19, 9),
    ));
    await db.projectDao.insert(Project(
      id: 'b',
      name: 'Beta',
      createdAt: DateTime(2026, 5, 19, 10),
    ));
    final all = await db.projectDao.getAll();
    expect(all.map((p) => p.id), ['b', 'a']); // ordered by createdAt desc
  });

  test('observationCount ignores soft-deleted', () async {
    await db.projectDao.insert(Project(
      id: 'p',
      name: 'P',
      createdAt: DateTime(2026, 5, 19),
    ));
    final now = DateTime(2026, 5, 19, 10);
    await db.observationDao.insert(Observation(
      id: 'o1',
      projectId: 'p',
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
    await db.observationDao.insert(Observation(
      id: 'o2',
      projectId: 'p',
      description: '',
      lat: 0,
      lon: 0,
      altitude: null,
      accuracy: null,
      manualPlacement: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: now,
    ));
    expect(await db.projectDao.observationCount('p'), 1);
  });

  test('delete cascades to observations', () async {
    await db.projectDao.insert(Project(
      id: 'p',
      name: 'P',
      createdAt: DateTime(2026, 5, 19),
    ));
    final now = DateTime(2026, 5, 19, 10);
    await db.observationDao.insert(Observation(
      id: 'o1',
      projectId: 'p',
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
    await db.projectDao.deleteById('p');
    expect(await db.observationDao.activeForProject('p'), isEmpty);
  });
}
