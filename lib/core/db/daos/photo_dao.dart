import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'photo_dao.g.dart';

@DriftAccessor(tables: [Photos, Observations])
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

  /// Stream every non-deleted photo belonging to observations in [projectId],
  /// most recently taken first.
  Stream<List<Photo>> watchForProject(String projectId) {
    final query = select(photos).join([
      innerJoin(observations, observations.id.equalsExp(photos.observationId)),
    ])
      ..where(observations.projectId.equals(projectId) &
          observations.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(photos.takenAt)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(photos)).toList());
  }

  Future<void> insert(Photo photo) => into(photos).insert(photo.toCompanion(false));

  Future<int> deleteById(String id) =>
      (delete(photos)..where((t) => t.id.equals(id))).go();

  Future<int> deleteForObservation(String observationId) =>
      (delete(photos)..where((t) => t.observationId.equals(observationId))).go();
}
