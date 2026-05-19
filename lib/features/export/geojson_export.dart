import 'dart:convert';

import '../../core/db/database.dart';

class GeoJsonExport {
  GeoJsonExport._();

  /// Build a GeoJSON FeatureCollection where:
  /// - Observations are Point features
  /// - Tracks are LineString features
  static String build({
    required Project project,
    required List<Observation> observations,
    required Map<String, List<Photo>> photosByObservation,
    required Map<String, List<TrackPoint>> tracksByTrackId,
  }) {
    final features = <Map<String, Object?>>[];

    for (final o in observations) {
      final photos = photosByObservation[o.id] ?? const <Photo>[];
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          // GeoJSON is [lon, lat, alt]
          'coordinates': o.altitude != null
              ? [o.lon, o.lat, o.altitude]
              : [o.lon, o.lat],
        },
        'properties': {
          'id': o.id,
          'description': o.description,
          'createdAt': o.createdAt.toUtc().toIso8601String(),
          'updatedAt': o.updatedAt.toUtc().toIso8601String(),
          'accuracy': o.accuracy,
          'manualPlacement': o.manualPlacement,
          'photos': photos
              .map((p) => {
                    'file': _fileName(p.filePath),
                    'bearing': p.bearing,
                    'altitude': p.altitude,
                    'takenAt': p.takenAt.toUtc().toIso8601String(),
                  })
              .toList(),
        },
      });
    }

    for (final entry in tracksByTrackId.entries) {
      final points = entry.value;
      if (points.length < 2) continue;
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': points
              .map((p) => p.altitude != null
                  ? [p.lon, p.lat, p.altitude]
                  : [p.lon, p.lat])
              .toList(),
        },
        'properties': {
          'trackId': entry.key,
          'startedAt': points.first.recordedAt.toUtc().toIso8601String(),
          'endedAt': points.last.recordedAt.toUtc().toIso8601String(),
          'pointCount': points.length,
        },
      });
    }

    final collection = {
      'type': 'FeatureCollection',
      'name': project.name,
      'features': features,
    };
    return const JsonEncoder.withIndent('  ').convert(collection);
  }

  static String _fileName(String path) {
    final i = path.lastIndexOf(RegExp(r'[\\/]'));
    return i == -1 ? path : path.substring(i + 1);
  }
}
