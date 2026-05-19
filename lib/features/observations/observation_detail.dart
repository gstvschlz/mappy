import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import '../map/tile_sources.dart';
import 'tag_widgets.dart';

class ObservationDetailScreen extends ConsumerStatefulWidget {
  const ObservationDetailScreen({super.key, required this.observationId});

  final String observationId;

  @override
  ConsumerState<ObservationDetailScreen> createState() =>
      _ObservationDetailScreenState();
}

class _ObservationDetailScreenState
    extends ConsumerState<ObservationDetailScreen> {
  late final TextEditingController _descController;
  Observation? _observation;
  bool _editing = false;
  List<String> _pendingTags = const [];

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final obs = await db.observationDao.getById(widget.observationId);
    if (!mounted || obs == null) return;
    final currentTags =
        await db.tagDao.watchForObservation(obs.id).first;
    if (!mounted) return;
    setState(() {
      _observation = obs;
      _descController.text = obs.description;
      _pendingTags = currentTags.map((t) => t.name).toList();
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _enterEdit() async {
    final obs = _observation;
    if (obs == null) return;
    final db = ref.read(appDatabaseProvider);
    final currentTags = await db.tagDao.watchForObservation(obs.id).first;
    if (!mounted) return;
    setState(() {
      _editing = true;
      _pendingTags = currentTags.map((t) => t.name).toList();
    });
  }

  Future<void> _saveEdit() async {
    final obs = _observation;
    if (obs == null) return;
    final db = ref.read(appDatabaseProvider);
    final updated = obs.copyWith(
      description: _descController.text.trim(),
      updatedAt: DateTime.now(),
    );
    await db.observationDao.updateObservation(updated);
    await db.tagDao.setTagsForObservation(
      observationId: obs.id,
      projectId: obs.projectId,
      names: _pendingTags,
    );
    if (!mounted) return;
    setState(() {
      _observation = updated;
      _editing = false;
    });
  }

  Future<void> _softDelete() async {
    final db = ref.read(appDatabaseProvider);
    await db.observationDao.softDelete(widget.observationId, DateTime.now());
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final obs = _observation;
    if (obs == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Observation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Observation'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_editing) {
                _saveEdit();
              } else {
                _enterEdit();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Move to trash?'),
                  content: const Text(
                      'You can restore from the trash screen later.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Trash'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) _softDelete();
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(obs.lat, obs.lon),
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: TileSource.topo.urlTemplate,
                  subdomains: TileSource.topo.subdomains,
                  userAgentPackageName: 'com.scholze.mappy',
                  tileProvider: NetworkTileProvider(
                    headers: const {
                      'User-Agent':
                          'mappy/0.1 (geological field mapping; com.scholze.mappy)'
                    },
                  ),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(obs.lat, obs.lon),
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created: ${fmt.format(obs.createdAt.toLocal())}'),
                Text(
                  'Location: ${obs.lat.toStringAsFixed(6)}, ${obs.lon.toStringAsFixed(6)}'
                  '${obs.altitude != null ? ' · ${obs.altitude!.toStringAsFixed(0)} m' : ''}',
                ),
                if (obs.accuracy != null)
                  Text('Accuracy: ±${obs.accuracy!.toStringAsFixed(0)} m'),
                if (obs.manualPlacement)
                  const Text('Manually placed (long-press on map)'),
                const SizedBox(height: 16),
                if (_editing)
                  TextField(
                    controller: _descController,
                    maxLines: 8,
                    minLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  )
                else
                  Text(
                    obs.description.isEmpty
                        ? '(no description)'
                        : obs.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 20),
                Text('Tags', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _TagsSection(
                  observation: obs,
                  editing: _editing,
                  pendingTags: _pendingTags,
                  onChanged: (next) => setState(() => _pendingTags = next),
                ),
                const SizedBox(height: 20),
                Text('Photos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                StreamBuilder<List<Photo>>(
                  stream: db.photoDao.watchForObservation(obs.id),
                  builder: (ctx, snap) {
                    final photos = snap.data ?? const <Photo>[];
                    if (photos.isEmpty) {
                      return const Text('No photos.');
                    }
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: photos.map((p) {
                        final file = File(p.filePath);
                        return GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _PhotoFullScreen(file: file),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : const ColoredBox(
                                    color: Colors.black12,
                                    child: Center(
                                        child: Icon(Icons.broken_image)),
                                  ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoFullScreen extends StatelessWidget {
  const _PhotoFullScreen({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(file),
        ),
      ),
    );
  }
}

class _TagsSection extends ConsumerWidget {
  const _TagsSection({
    required this.observation,
    required this.editing,
    required this.pendingTags,
    required this.onChanged,
  });

  final Observation observation;
  final bool editing;
  final List<String> pendingTags;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    if (editing) {
      return TagsEditor(
        projectId: observation.projectId,
        tags: pendingTags,
        onChanged: onChanged,
      );
    }
    return StreamBuilder<List<Tag>>(
      stream: db.tagDao.watchForObservation(observation.id),
      builder: (ctx, snap) {
        final tags = snap.data ?? const <Tag>[];
        if (tags.isEmpty) {
          return Text(
            'No tags. Tap edit to add some.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags.map((t) => TagChip(name: t.name)).toList(),
        );
      },
    );
  }
}
