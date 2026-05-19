import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'observation_dao.g.dart';

@DriftAccessor(tables: [Observations, Photos])
class ObservationDao extends DatabaseAccessor<AppDatabase>
    with _$ObservationDaoMixin {
  ObservationDao(super.db);

  Stream<List<Observation>> watchActiveForProject(String projectId) {
    return (select(observations)
          ..where((t) =>
              t.projectId.equals(projectId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<Observation>> watchTrashedForProject(String projectId) {
    return (select(observations)
          ..where((t) =>
              t.projectId.equals(projectId) & t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .watch();
  }

  Future<List<Observation>> activeForProject(String projectId) {
    return (select(observations)
          ..where((t) =>
              t.projectId.equals(projectId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<Observation?> getById(String id) =>
      (select(observations)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insert(Observation observation) =>
      into(observations).insert(observation.toCompanion(false));

  Future<bool> updateObservation(Observation observation) =>
      update(observations).replace(observation);

  Future<void> softDelete(String id, DateTime when) {
    return (update(observations)..where((t) => t.id.equals(id))).write(
      ObservationsCompanion(
        deletedAt: Value(when),
        updatedAt: Value(when),
      ),
    );
  }

  Future<void> restore(String id, DateTime when) {
    return (update(observations)..where((t) => t.id.equals(id))).write(
      ObservationsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(when),
      ),
    );
  }

  Future<int> hardDelete(String id) =>
      (delete(observations)..where((t) => t.id.equals(id))).go();

  Stream<List<Observation>> watchSearch(String projectId, String query) {
    final like = '%${query.toLowerCase()}%';
    return (select(observations)
          ..where((t) =>
              t.projectId.equals(projectId) &
              t.deletedAt.isNull() &
              t.description.lower().like(like))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }
}
