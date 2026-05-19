import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'project_dao.g.dart';

@DriftAccessor(tables: [Projects, Observations])
class ProjectDao extends DatabaseAccessor<AppDatabase> with _$ProjectDaoMixin {
  ProjectDao(super.db);

  Stream<List<Project>> watchAll() =>
      (select(projects)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<List<Project>> getAll() =>
      (select(projects)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<Project?> getById(String id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insert(Project project) =>
      into(projects).insert(project.toCompanion(false));

  Future<bool> updateProject(Project project) =>
      update(projects).replace(project);

  Future<int> deleteById(String id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  Future<int> observationCount(String projectId) async {
    final count = countAll(
      filter: observations.projectId.equals(projectId) &
          observations.deletedAt.isNull(),
    );
    final row = await (selectOnly(observations)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }
}
