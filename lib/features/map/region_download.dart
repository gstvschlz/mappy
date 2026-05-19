import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import 'fmtc_init.dart';
import 'tile_sources.dart';

class RegionDownloadScreen extends StatefulWidget {
  const RegionDownloadScreen({
    super.key,
    required this.currentCenter,
    required this.currentZoom,
  });

  final LatLng currentCenter;
  final double currentZoom;

  @override
  State<RegionDownloadScreen> createState() => _RegionDownloadScreenState();
}

class _RegionDownloadScreenState extends State<RegionDownloadScreen> {
  late LatLng _ne;
  late LatLng _sw;
  late final MapController _mapController = MapController();

  int _minZoom = 12;
  int _maxZoom = 17;
  TileSource _source = TileSource.osm;

  bool _downloading = false;
  int _completedTiles = 0;
  int _totalTiles = 0;
  StreamSubscription<DownloadProgress>? _downloadSub;

  @override
  void initState() {
    super.initState();
    final delta = 0.02;
    _ne = LatLng(widget.currentCenter.latitude + delta,
        widget.currentCenter.longitude + delta);
    _sw = LatLng(widget.currentCenter.latitude - delta,
        widget.currentCenter.longitude - delta);
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  LatLngBounds get _bounds => LatLngBounds(_sw, _ne);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-download region'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.currentCenter,
                initialZoom: widget.currentZoom,
              ),
              children: [
                TileLayer(
                  urlTemplate: _source.urlTemplate,
                  subdomains: _source.subdomains,
                  userAgentPackageName: 'com.scholze.mappy',
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: [
                        _sw,
                        LatLng(_sw.latitude, _ne.longitude),
                        _ne,
                        LatLng(_ne.latitude, _sw.longitude),
                      ],
                      color:
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                      borderColor: Theme.of(context).colorScheme.primary,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButton<TileSource>(
                    value: _source,
                    isExpanded: true,
                    items: TileSource.values
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ))
                        .toList(),
                    onChanged: _downloading
                        ? null
                        : (v) => setState(() {
                              if (v != null) _source = v;
                              if (_maxZoom > _source.maxZoom) {
                                _maxZoom = _source.maxZoom;
                              }
                            }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Min zoom: $_minZoom',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Expanded(
                        child: Slider(
                          value: _minZoom.toDouble(),
                          min: 5,
                          max: _maxZoom.toDouble(),
                          divisions: (_maxZoom - 5).clamp(1, 20),
                          onChanged: _downloading
                              ? null
                              : (v) => setState(() => _minZoom = v.round()),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Max zoom: $_maxZoom',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Expanded(
                        child: Slider(
                          value: _maxZoom.toDouble(),
                          min: _minZoom.toDouble(),
                          max: _source.maxZoom.toDouble(),
                          divisions:
                              (_source.maxZoom - _minZoom).clamp(1, 20),
                          onChanged: _downloading
                              ? null
                              : (v) => setState(() => _maxZoom = v.round()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _coordChip('NE', _ne),
                      _coordChip('SW', _sw),
                      ActionChip(
                        label: const Text('Use current view as region'),
                        onPressed: _downloading ? null : _useCurrentViewport,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_downloading)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: _totalTiles == 0
                              ? null
                              : _completedTiles / _totalTiles,
                        ),
                        const SizedBox(height: 4),
                        Text('$_completedTiles / $_totalTiles tiles'),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _startDownload,
                            icon: const Icon(Icons.download),
                            label: const Text('Download'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordChip(String label, LatLng p) => Chip(
        label: Text(
          '$label: ${p.latitude.toStringAsFixed(4)}, '
          '${p.longitude.toStringAsFixed(4)}',
        ),
      );

  void _useCurrentViewport() {
    final bounds = _mapController.camera.visibleBounds;
    setState(() {
      _ne = bounds.northEast;
      _sw = bounds.southWest;
    });
  }

  Future<void> _startDownload() async {
    await FmtcInit.ensure();
    final store = FmtcInit.storeFor(_source);
    final region = RectangleRegion(_bounds).toDownloadable(
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      options: TileLayer(
        urlTemplate: _source.urlTemplate,
        subdomains: _source.subdomains,
        userAgentPackageName: 'com.scholze.mappy',
        tileProvider: FMTCTileProvider(
          stores: {_source.id: BrowseStoreStrategy.readUpdateCreate},
          headers: const {
            'User-Agent':
                'Mappy/0.1 (geological field mapping; com.scholze.mappy)'
          },
        ),
      ),
    );

    setState(() {
      _downloading = true;
      _completedTiles = 0;
      _totalTiles = 0;
    });

    final progressStream =
        store.download.startForeground(region: region).downloadProgress;
    _downloadSub = progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        _completedTiles = progress.attemptedTilesCount;
        _totalTiles = progress.maxTilesCount;
      });
    }, onDone: () {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Region downloaded.')),
      );
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    });
  }
}
