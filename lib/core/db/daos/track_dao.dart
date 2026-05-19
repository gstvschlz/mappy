import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'track_dao.g.dart';

@DriftAccessor(tables: [TrackPoints])
class TrackDao extends DatabaseAccessor<AppDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  Future<void> insertPoint(TrackPointsCompanion point) =>
      into(trackPoints).insert(point);

  Future<List<TrackPoint>> forProject(String projectId) {
    return (select(trackPoints)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.asc(t.recordedAt)]))
        .get();
  }

  Stream<List<TrackPoint>> watchForProject(String projectId) {
    return (select(trackPoints)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.asc(t.recordedAt)]))
        .watch();
  }

  Future<List<TrackPoint>> forTrack(String trackId) {
    return (select(trackPoints)
          ..where((t) => t.trackId.equals(trackId))
          ..orderBy([(t) => OrderingTerm.asc(t.recordedAt)]))
        .get();
  }

  Future<List<String>> distinctTrackIds(String projectId) async {
    final query = selectOnly(trackPoints, distinct: true)
      ..addColumns([trackPoints.trackId])
      ..where(trackPoints.projectId.equals(projectId));
    final rows = await query.get();
    return rows.map((r) => r.read(trackPoints.trackId)!).toList();
  }

  Future<int> deleteTrack(String trackId) =>
      (delete(trackPoints)..where((t) => t.trackId.equals(trackId))).go();
}
