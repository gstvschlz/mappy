import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import '../observations/observation_detail.dart';

final _photosForProjectProvider =
    StreamProvider.family<List<Photo>, String>((ref, projectId) {
  return ref.watch(appDatabaseProvider).photoDao.watchForProject(projectId);
});

final _observationsCountProvider =
    StreamProvider.family<int, String>((ref, projectId) {
  return ref
      .watch(appDatabaseProvider)
      .observationDao
      .watchActiveForProject(projectId)
      .map((list) => list.length);
});

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(_photosForProjectProvider(project.id));
    final countAsync = ref.watch(_observationsCountProvider(project.id));
    final dateFmt = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Created ${dateFmt.format(project.createdAt.toLocal())}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.place_outlined,
                        label: countAsync.when(
                          data: (n) => '$n observations',
                          loading: () => '…',
                          error: (_, __) => '—',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.photo_library_outlined,
                        label: photosAsync.when(
                          data: (p) => '${p.length} photos',
                          loading: () => '…',
                          error: (_, __) => '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Photos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          photosAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $e'),
              ),
            ),
            data: (photos) {
              if (photos.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Text(
                      'No photos yet. Add observations with photos to see them here.',
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _PhotoTile(photo: photos[i]),
                    childCount: photos.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});
  final Photo photo;

  @override
  Widget build(BuildContext context) {
    final file = File(photo.filePath);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ObservationDetailScreen(
              observationId: photo.observationId,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: file.existsSync()
            ? Image.file(
                file,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
      ),
    );
  }
}
