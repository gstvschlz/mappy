import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'tile_sources.dart';

/// Initializes FMTC and creates one store per [TileSource] so each map source
/// has its own cache and can be pre-downloaded independently.
class FmtcInit {
  FmtcInit._();

  static bool _initialized = false;

  static Future<void> ensure() async {
    if (_initialized) return;
    await FMTCObjectBoxBackend().initialise();
    for (final src in TileSource.values) {
      await FMTCStore(src.id).manage.create();
    }
    _initialized = true;
  }

  static FMTCStore storeFor(TileSource src) => FMTCStore(src.id);
}
