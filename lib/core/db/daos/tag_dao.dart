import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, ObservationTags, Observations])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  /// All tags defined in [projectId], alphabetical, for autocomplete sources.
  Stream<List<Tag>> watchForProject(String projectId) {
    return (select(tags)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Tags currently attached to [observationId], alphabetical.
  Stream<List<Tag>> watchForObservation(String observationId) {
    final q = select(tags).join([
      innerJoin(
        observationTags,
        observationTags.tagId.equalsExp(tags.id),
      ),
    ])
      ..where(observationTags.observationId.equals(observationId))
      ..orderBy([OrderingTerm.asc(tags.name)]);
    return q.watch().map((rows) => rows.map((r) => r.readTable(tags)).toList());
  }

  /// Find a tag in [projectId] whose name matches [name] (case-insensitive),
  /// or create it.
  Future<Tag> upsertByName(String projectId, String name) async {
    final trimmed = name.trim();
    final existing = await (select(tags)
          ..where((t) =>
              t.projectId.equals(projectId) &
              t.name.lower().equals(trimmed.toLowerCase()))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;
    final tag = Tag(
      id: const Uuid().v4(),
      projectId: projectId,
      name: trimmed,
      createdAt: DateTime.now(),
    );
    await into(tags).insert(tag);
    return tag;
  }

  /// Replace the tag set on [observationId] with the canonical names in
  /// [names]. Tags are looked up or created within [projectId]. Returns the
  /// resulting tag list.
  Future<List<Tag>> setTagsForObservation({
    required String observationId,
    required String projectId,
    required List<String> names,
  }) async {
    return transaction(() async {
      final deduped = <String, String>{};
      for (final raw in names) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;
        deduped.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
      }
      final desired = <Tag>[];
      for (final name in deduped.values) {
        desired.add(await upsertByName(projectId, name));
      }
      await (delete(observationTags)
            ..where((t) => t.observationId.equals(observationId)))
          .go();
      if (desired.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            observationTags,
            desired.map(
              (t) => ObservationTagsCompanion.insert(
                observationId: observationId,
                tagId: t.id,
              ),
            ),
          );
        });
      }
      return desired;
    });
  }

  /// Detach a single tag from an observation without deleting the tag itself.
  Future<int> detach(String observationId, String tagId) {
    return (delete(observationTags)
          ..where((t) =>
              t.observationId.equals(observationId) & t.tagId.equals(tagId)))
        .go();
  }
}
