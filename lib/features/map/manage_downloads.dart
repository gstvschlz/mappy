import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'fmtc_init.dart';
import 'tile_sources.dart';

/// Lists every TileSource alongside its FMTC store's cached-tile count and
/// disk usage, with a per-source "Clear" action that resets the store.
class ManageDownloadsScreen extends StatefulWidget {
  const ManageDownloadsScreen({super.key});

  @override
  State<ManageDownloadsScreen> createState() => _ManageDownloadsScreenState();
}

class _ManageDownloadsScreenState extends State<ManageDownloadsScreen> {
  // Keyed by TileSource.id; re-fetched on screen open and after any clear.
  final Map<String, _StoreStats?> _stats = {};
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await FmtcInit.ensure();
      for (final src in TileSource.values) {
        final store = FmtcInit.storeFor(src);
        final all = await store.stats.all;
        if (!mounted) return;
        _stats[src.id] = _StoreStats(
          sizeKiB: all.size,
          length: all.length,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _clear(TileSource src) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Clear cached tiles for ${src.label}?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'This deletes every tile downloaded for this source. The next '
            'time you visit an area you\'ll need to be online to fetch '
            'tiles again. Your observations and tracks are not affected.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final store = FmtcInit.storeFor(src);
      await store.manage.reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t clear ${src.label}: $e')),
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-downloaded tiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: _error != null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Could not load cache stats:\n$_error',
                  style: TextStyle(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    'Tiles you have pre-downloaded for offline use. '
                    'Clearing a source frees up space; you can re-download '
                    'a region anytime.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: Colors.white,
                    child: Column(
                      children: [
                        for (var i = 0; i < TileSource.values.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Divider(
                                height: 0.5,
                                thickness: 0.5,
                                color:
                                    scheme.onSurface.withValues(alpha: 0.08),
                              ),
                            ),
                          _SourceRow(
                            source: TileSource.values[i],
                            stats: _stats[TileSource.values[i].id],
                            loading: _refreshing,
                            onClear: () => _clear(TileSource.values[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StoreStats {
  const _StoreStats({required this.sizeKiB, required this.length});
  final double sizeKiB;
  final int length;

  String get sizeLabel {
    if (length == 0) return '—';
    if (sizeKiB < 1024) return '${sizeKiB.toStringAsFixed(0)} KiB';
    final mib = sizeKiB / 1024;
    if (mib < 1024) return '${mib.toStringAsFixed(1)} MiB';
    return '${(mib / 1024).toStringAsFixed(2)} GiB';
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.stats,
    required this.loading,
    required this.onClear,
  });

  final TileSource source;
  final _StoreStats? stats;
  final bool loading;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasTiles = (stats?.length ?? 0) > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.square_stack_3d_down_right_fill,
              size: 18,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                if (loading && stats == null)
                  Text(
                    'Reading…',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  )
                else
                  Text(
                    stats == null
                        ? '—'
                        : hasTiles
                            ? '${stats!.length} tiles · ${stats!.sizeLabel}'
                            : 'No cached tiles',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: hasTiles ? onClear : null,
            child: Text(
              'Clear',
              style: TextStyle(
                color: hasTiles ? scheme.error : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
