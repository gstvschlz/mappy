import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import '../projects/active_project.dart';
import 'empty_state.dart';
import 'observation_detail.dart';
import 'trash_screen.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');

final filteredObservationsProvider =
    StreamProvider<List<Observation>>((ref) {
  final active = ref.watch(activeProjectProvider).value;
  // Yielding an empty list immediately (instead of Stream.empty(), which
  // never emits) lets the consumer's `.when(data: ...)` actually render the
  // empty-state UI instead of spinning forever.
  if (active == null) return Stream.value(const []);
  final q = ref.watch(_searchQueryProvider).trim();
  final dao = ref.watch(appDatabaseProvider).observationDao;
  if (q.isEmpty) return dao.watchActiveForProject(active.id);
  return dao.watchSearch(active.id, q);
});

class ObservationListScreen extends ConsumerWidget {
  const ObservationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncObs = ref.watch(filteredObservationsProvider);
    final active = ref.watch(activeProjectProvider).value;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(active?.name ?? 'Observations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Trash',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search descriptions',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) =>
                  ref.read(_searchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: asyncObs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  final searching =
                      ref.watch(_searchQueryProvider).trim().isNotEmpty;
                  return EmptyState(
                    icon: searching
                        ? CupertinoIcons.search
                        : CupertinoIcons.doc_text_search,
                    title: 'Oops! Nothing here!',
                    body: active == null
                        ? 'Create or pick a project on the Projects tab to '
                            'see its observations here.'
                        : searching
                            ? 'No observations match your search.'
                            : 'You haven\'t added any observations to '
                                '"${active.name}" yet. Tap "New observation" '
                                'on the Map tab to start.',
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (ctx, i) {
                    final o = list[i];
                    return ListTile(
                      leading: _Thumbnail(observationId: o.id),
                      title: Text(
                        o.description.isEmpty
                            ? '(no description)'
                            : o.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${fmt.format(o.createdAt.toLocal())} · '
                        '${o.lat.toStringAsFixed(5)}, ${o.lon.toStringAsFixed(5)}'
                        '${o.manualPlacement ? ' · manual' : ''}',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ObservationDetailScreen(observationId: o.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.observationId});

  final String observationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(appDatabaseProvider).photoDao;
    return StreamBuilder<List<Photo>>(
      stream: dao.watchForObservation(observationId),
      builder: (ctx, snap) {
        final photos = snap.data ?? const <Photo>[];
        if (photos.isEmpty) {
          return const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.image_not_supported_outlined),
          );
        }
        final f = File(photos.first.filePath);
        if (!f.existsSync()) {
          return const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.broken_image_outlined),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(f, width: 56, height: 56, fit: BoxFit.cover),
        );
      },
    );
  }
}
