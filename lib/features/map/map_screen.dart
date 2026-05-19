import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import '../../core/location/location_service.dart';
import '../observations/new_observation_flow.dart';
import '../observations/observation_detail.dart';
import '../projects/active_project.dart';
import '../tracks/track_layer.dart';
import '../tracks/track_recorder.dart';
import 'fmtc_init.dart';
import 'measure_tool.dart';
import 'region_download.dart';
import 'tile_sources.dart';

const _kTileSourcePrefKey = 'mappy.tileSourceId';

final tileSourceProvider =
    StateNotifierProvider<TileSourceController, TileSource>((ref) {
  return TileSourceController();
});

class TileSourceController extends StateNotifier<TileSource> {
  TileSourceController() : super(TileSource.topo) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kTileSourcePrefKey);
    if (id != null) state = TileSource.fromId(id);
  }

  Future<void> set(TileSource src) async {
    state = src;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTileSourcePrefKey, src.id);
  }
}

final observationsForActiveProjectProvider =
    StreamProvider<List<Observation>>((ref) {
  final active = ref.watch(activeProjectProvider).value;
  if (active == null) return const Stream.empty();
  return ref.watch(appDatabaseProvider).observationDao
      .watchActiveForProject(active.id);
});

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _followGps = true;
  MeasureMode? _measure;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final src = ref.watch(tileSourceProvider);
    final positionAsync = ref.watch(currentPositionProvider);
    final observationsAsync =
        ref.watch(observationsForActiveProjectProvider);
    final active = ref.watch(activeProjectProvider).value;
    final trackingState = ref.watch(trackRecorderProvider);

    final position = positionAsync.value;
    final center = position != null
        ? LatLng(position.latitude, position.longitude)
        : const LatLng(-15.78, -47.93); // Brasília fallback

    if (_followGps && position != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(LatLng(position.latitude, position.longitude),
            _mapController.camera.zoom);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(active?.name ?? 'Mappy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            tooltip: 'Tile source',
            onPressed: _showTileSourceSheet,
          ),
          IconButton(
            icon: const Icon(Icons.download_for_offline),
            tooltip: 'Pre-download region',
            onPressed: () => _openRegionDownload(context),
          ),
          IconButton(
            icon: Icon(_measure == null
                ? Icons.straighten
                : Icons.straighten,
                color: _measure == null
                    ? null
                    : Theme.of(context).colorScheme.primary),
            tooltip: 'Measure',
            onPressed: _toggleMeasure,
          ),
          IconButton(
            icon: Icon(
              trackingState.isRecording
                  ? Icons.fiber_manual_record
                  : Icons.timeline,
              color: trackingState.isRecording ? Colors.red : null,
            ),
            tooltip: trackingState.isRecording
                ? 'Stop track'
                : 'Start track',
            onPressed: active == null
                ? null
                : () => _toggleTrack(active.id),
          ),
        ],
      ),
      floatingActionButton: active == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_follow',
                  onPressed: () {
                    if (position != null) {
                      _mapController.move(
                        LatLng(position.latitude, position.longitude),
                        _mapController.camera.zoom < 14
                            ? 16
                            : _mapController.camera.zoom,
                      );
                      setState(() => _followGps = true);
                    }
                  },
                  child: Icon(
                    _followGps ? Icons.my_location : Icons.location_searching,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'fab_new_obs',
                  onPressed: () => _newObservation(context),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('New observation'),
                ),
              ],
            ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: src.maxZoom.toDouble(),
              onTap: (tapPos, point) {
                if (_measure != null) {
                  setState(() => _measure!.addPoint(point));
                }
              },
              onLongPress: (tapPos, point) =>
                  _newObservationAt(context, point),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _followGps) {
                  setState(() => _followGps = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: src.urlTemplate,
                subdomains: src.subdomains,
                userAgentPackageName: 'com.scholze.mappy',
                tileProvider: FMTCTileProvider(
                  stores: {src.id: BrowseStoreStrategy.readUpdateCreate},
                  loadingStrategy: BrowseLoadingStrategy.onlineFirst,
                  headers: {
                    'User-Agent':
                        'Mappy/0.1 (geological field mapping; com.scholze.mappy)'
                  },
                  errorHandler: (exception) {
                    debugPrint('FMTC tile error: ${exception.type} '
                        '${exception.message}');
                    return null;
                  },
                ),
                maxNativeZoom: src.maxZoom,
                errorTileCallback: (tile, error, stack) {
                  debugPrint(
                      'TileLayer error for ${tile.coordinates}: $error');
                },
              ),
              if (active != null) TrackLayer(projectId: active.id),
              MarkerLayer(
                markers: [
                  ...observationsAsync.maybeWhen(
                    data: (list) => list.map((o) => Marker(
                          point: LatLng(o.lat, o.lon),
                          width: 36,
                          height: 36,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ObservationDetailScreen(observationId: o.id),
                              ),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.primary,
                              size: 36,
                            ),
                          ),
                        )),
                    orElse: () => const <Marker>[],
                  ),
                  if (position != null)
                    Marker(
                      point: LatLng(position.latitude, position.longitude),
                      width: 24,
                      height: 24,
                      child: const _GpsDot(),
                    ),
                ],
              ),
              if (_measure != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _measure!.points,
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ],
                ),
              if (_measure != null && _measure!.points.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _measure!.points,
                      color: Theme.of(context)
                          .colorScheme
                          .tertiary
                          .withValues(alpha: 0.15),
                      borderStrokeWidth: 0,
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: [TextSourceAttribution(src.attribution)],
              ),
            ],
          ),
          if (active == null)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x88000000),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Create or select a project to start mapping.',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          if (_measure != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text(_measure!.summary())),
                      IconButton(
                        icon: const Icon(Icons.undo),
                        onPressed: _measure!.points.isEmpty
                            ? null
                            : () => setState(() => _measure!.removeLast()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _measure = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (position != null)
            Positioned(
              bottom: 16,
              left: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  child: Text(
                    '${position.latitude.toStringAsFixed(6)}, '
                    '${position.longitude.toStringAsFixed(6)}'
                    '${position.accuracy.isFinite ? ' (±${position.accuracy.toStringAsFixed(0)} m)' : ''}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showTileSourceSheet() async {
    final current = ref.read(tileSourceProvider);
    final picked = await showModalBottomSheet<TileSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in TileSource.values)
              ListTile(
                leading: Icon(
                  s == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(s.label),
                subtitle: Text(s.attribution),
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(tileSourceProvider.notifier).set(picked);
    }
  }

  Future<void> _openRegionDownload(BuildContext context) async {
    await FmtcInit.ensure();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegionDownloadScreen(
          currentCenter: _mapController.camera.center,
          currentZoom: _mapController.camera.zoom,
        ),
      ),
    );
  }

  void _toggleMeasure() {
    setState(() {
      _measure = _measure == null ? MeasureMode() : null;
    });
  }

  Future<void> _toggleTrack(String projectId) async {
    final notifier = ref.read(trackRecorderProvider.notifier);
    if (ref.read(trackRecorderProvider).isRecording) {
      await notifier.stop();
    } else {
      await notifier.start(projectId);
    }
  }

  Future<void> _newObservation(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewObservationFlow()),
    );
  }

  Future<void> _newObservationAt(BuildContext context, LatLng point) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewObservationFlow(manualPoint: point),
      ),
    );
  }
}

class _GpsDot extends StatelessWidget {
  const _GpsDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
      ),
    );
  }
}
