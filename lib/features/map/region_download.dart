import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'fmtc_init.dart';
import 'manage_downloads.dart';
import 'tile_sources.dart';

const _kUserAgent =
    'mappy/0.1 (geological field mapping; com.scholze.mappy)';

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
  int _maxZoom = 15;
  TileSource _source = TileSource.topo;

  bool _downloading = false;
  int _completedTiles = 0;
  int _totalTiles = 0;
  int _successCount = 0;
  int _failCount = 0;
  String? _lastError;
  StreamSubscription<DownloadProgress>? _downloadSub;
  StreamSubscription<TileEvent>? _eventsSub;
  bool _probing = false;
  String? _probeResult;

  @override
  void initState() {
    super.initState();
    const delta = 0.02;
    _ne = LatLng(widget.currentCenter.latitude + delta,
        widget.currentCenter.longitude + delta);
    _sw = LatLng(widget.currentCenter.latitude - delta,
        widget.currentCenter.longitude - delta);
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _eventsSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  LatLngBounds get _bounds => LatLngBounds(_sw, _ne);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-download region'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Manage downloaded tiles',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ManageDownloadsScreen(),
              ),
            ),
          ),
        ],
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
                  tileProvider: NetworkTileProvider(
                    // Not const: TileLayer mutates this map.
                    headers: {'User-Agent': _kUserAgent},
                  ),
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.18),
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
                              _probeResult = null;
                            }),
                  ),
                  const SizedBox(height: 8),
                  _ZoomRow(
                    label: 'Min zoom',
                    value: _minZoom,
                    min: 5,
                    max: _maxZoom,
                    enabled: !_downloading,
                    onChanged: (v) => setState(() => _minZoom = v),
                  ),
                  _ZoomRow(
                    label: 'Max zoom',
                    value: _maxZoom,
                    min: _minZoom,
                    max: _source.maxZoom,
                    enabled: !_downloading,
                    onChanged: (v) => setState(() => _maxZoom = v),
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
                    _DownloadingStatus(
                      completed: _completedTiles,
                      total: _totalTiles,
                      success: _successCount,
                      failed: _failCount,
                      lastError: _lastError,
                      onCancel: _cancelDownload,
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _startDownload,
                            icon: const Icon(Icons.download),
                            label: const Text('Download'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _probing ? null : _probeTileServer,
                          icon: _probing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check),
                          label: const Text('Test fetch'),
                        ),
                      ],
                    ),
                    if (_probeResult != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _probeResult!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
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

  /// Fires a single direct HTTP GET to a representative tile so the user can
  /// see, with their own eyes, whether the network path is reachable, whether
  /// the server is returning 200, and what FMTC's downloader will actually be
  /// hitting. This bypasses FMTC entirely.
  Future<void> _probeTileServer() async {
    setState(() {
      _probing = true;
      _probeResult = null;
    });
    final coords = _probeCoords();
    final url = _source.urlTemplate
        .replaceAll('{z}', '${coords.z}')
        .replaceAll('{x}', '${coords.x}')
        .replaceAll('{y}', '${coords.y}')
        .replaceAll('{s}', _source.subdomains.isEmpty ? '' : _source.subdomains.first);
    final sb = StringBuffer()..writeln('GET $url');
    try {
      final resp = await http
          .get(Uri.parse(url), headers: const {'User-Agent': _kUserAgent})
          .timeout(const Duration(seconds: 12));
      sb
        ..writeln('HTTP ${resp.statusCode}')
        ..writeln('Content-Length: ${resp.bodyBytes.length} bytes')
        ..writeln(
            'Content-Type: ${resp.headers['content-type'] ?? '(none)'}');
      if (resp.statusCode != 200) {
        final preview = resp.body.length > 200
            ? '${resp.body.substring(0, 200)}…'
            : resp.body;
        sb.writeln('Body: $preview');
      }
    } on TimeoutException {
      sb.writeln('Timed out after 12s.');
    } catch (e) {
      sb.writeln('Error: $e');
    }
    if (!mounted) return;
    setState(() {
      _probing = false;
      _probeResult = sb.toString();
    });
  }

  ({int x, int y, int z}) _probeCoords() {
    // Standard slippy-map tile math: WGS84 lat/lon to (x, y, z).
    final lat = (_sw.latitude + _ne.latitude) / 2;
    final lon = (_sw.longitude + _ne.longitude) / 2;
    final z = _minZoom;
    final n = 1 << z;
    final x = ((lon + 180) / 360 * n).floor().clamp(0, n - 1);
    final latRad = lat * math.pi / 180;
    final y = ((1 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
            n)
        .floor()
        .clamp(0, n - 1);
    return (x: x, y: y, z: z);
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
          // Not const: TileLayer mutates this map.
          headers: {'User-Agent': _kUserAgent},
        ),
      ),
    );

    setState(() {
      _downloading = true;
      _completedTiles = 0;
      _totalTiles = 0;
      _successCount = 0;
      _failCount = 0;
      _lastError = null;
    });

    final streams = store.download.startForeground(
      region: region,
      // Be polite to free tile providers (OSM, OpenTopoMap, Esri community).
      parallelThreads: 2,
      rateLimit: 2,
      // skipSeaTiles probes (0,0,17) at start and counts ocean tiles as
      // "skipped" — for our purposes it just adds noise.
      skipSeaTiles: false,
    );

    _downloadSub = streams.downloadProgress.listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _completedTiles = progress.attemptedTilesCount;
          _totalTiles = progress.maxTilesCount;
          _successCount = progress.successfulTilesCount;
          _failCount = progress.failedTilesCount;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _failCount == 0
                  ? 'Region downloaded: $_successCount tiles.'
                  : 'Finished with $_failCount failures '
                      '($_successCount succeeded).',
            ),
          ),
        );
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _lastError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      },
    );

    _eventsSub = streams.tileEvents.listen((event) {
      if (!mounted) return;
      switch (event) {
        case NegativeResponseTileEvent(:final fetchResponse, :final url):
          debugPrint(
              'Tile HTTP ${fetchResponse.statusCode} for $url');
          setState(() {
            _lastError = 'HTTP ${fetchResponse.statusCode} '
                'for z=${event.coordinates.$3} '
                '(x=${event.coordinates.$1},y=${event.coordinates.$2})';
          });
          break;
        case FailedRequestTileEvent(:final fetchError, :final url):
          debugPrint('Tile network error for $url: $fetchError');
          setState(() => _lastError = 'Network: $fetchError');
          break;
        default:
          // Successful / skipped / sea — uninteresting for diagnostics.
          break;
      }
    });
  }

  Future<void> _cancelDownload() async {
    await _downloadSub?.cancel();
    await _eventsSub?.cancel();
    final store = FmtcInit.storeFor(_source);
    await store.download.cancel();
    if (!mounted) return;
    setState(() => _downloading = false);
  }
}

class _ZoomRow extends StatelessWidget {
  const _ZoomRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final divisions = (max - min).clamp(1, 30);
    return Row(
      children: [
        Expanded(
          child: Text('$label: $value',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions,
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
          ),
        ),
      ],
    );
  }
}

class _DownloadingStatus extends StatelessWidget {
  const _DownloadingStatus({
    required this.completed,
    required this.total,
    required this.success,
    required this.failed,
    required this.lastError,
    required this.onCancel,
  });

  final int completed;
  final int total;
  final int success;
  final int failed;
  final String? lastError;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: total == 0 ? null : completed / total,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('$completed / $total'),
            const Spacer(),
            Text(
              '$success ok',
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Text(
              '$failed failed',
              style: TextStyle(
                color: failed == 0 ? scheme.onSurfaceVariant : scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (lastError != null) ...[
          const SizedBox(height: 6),
          Text(
            'Last: $lastError',
            style: TextStyle(color: scheme.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.stop),
          label: const Text('Cancel'),
        ),
      ],
    );
  }
}
