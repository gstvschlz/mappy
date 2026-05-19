import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import '../projects/active_project.dart';

final _trashStreamProvider = StreamProvider<List<Observation>>((ref) {
  final active = ref.watch(activeProjectProvider).value;
  if (active == null) return const Stream.empty();
  return ref.watch(appDatabaseProvider).observationDao
      .watchTrashedForProject(active.id);
});

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncObs = ref.watch(_trashStreamProvider);
    final db = ref.watch(appDatabaseProvider);
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Trash')),
      body: asyncObs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Trash is empty.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (ctx, i) {
              final o = list[i];
              return ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(
                  o.description.isEmpty ? '(no description)' : o.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Deleted ${o.deletedAt == null ? '?' : fmt.format(o.deletedAt!.toLocal())}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore),
                      tooltip: 'Restore',
                      onPressed: () => db.observationDao
                          .restore(o.id, DateTime.now()),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever),
                      tooltip: 'Delete forever',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete forever?'),
                            content: const Text(
                                'This cannot be undone. Photos will be removed too.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton.tonal(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await db.observationDao.hardDelete(o.id);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
