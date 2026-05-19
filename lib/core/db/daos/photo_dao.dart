import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'photo_dao.g.dart';

@DriftAccessor(tables: [Photos])
class PhotoDao extends DatabaseAccessor<AppDatabase> with _$PhotoDaoMixin {
  PhotoDao(super.db);

  Future<List<Photo>> forObservation(String observationId) {
    return (select(photos)
          ..where((t) => t.observationId.equals(observationId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .get();
  }

  Stream<List<Photo>> watchForObservation(String observationId) {
    return (select(photos)
          ..where((t) => t.observationId.equals(observationId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .watch();
  }

  Future<void> insert(Photo photo) => into(photos).insert(photo.toCompanion(false));

  Future<int> deleteById(String id) =>
      (delete(photos)..where((t) => t.id.equals(id))).go();

  Future<int> deleteForObservation(String observationId) =>
      (delete(photos)..where((t) => t.observationId.equals(observationId))).go();
}
