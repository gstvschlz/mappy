import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import '../projects/active_project.dart';
import 'observation_detail.dart';
import 'trash_screen.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');

final filteredObservationsProvider =
    StreamProvider<List<Observation>>((ref) {
  final active = ref.watch(activeProjectProvider).value;
  if (active == null) return const Stream.empty();
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
                  return const Center(child: Text('No observations.'));
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
