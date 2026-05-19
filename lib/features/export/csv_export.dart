import 'package:csv/csv.dart';

import '../../core/db/database.dart';

class CsvExport {
  CsvExport._();

  static String buildObservations({
    required List<Observation> observations,
    required Map<String, List<Photo>> photosByObservation,
  }) {
    final rows = <List<Object?>>[
      [
        'id',
        'description',
        'lat',
        'lon',
        'altitude_m',
        'accuracy_m',
        'manual_placement',
        'created_at_utc',
        'updated_at_utc',
        'photo_files',
      ],
    ];
    for (final o in observations) {
      final photos = photosByObservation[o.id] ?? const <Photo>[];
      rows.add([
        o.id,
        o.description.replaceAll('\n', ' \\n '),
        o.lat,
        o.lon,
        o.altitude,
        o.accuracy,
        o.manualPlacement,
        o.createdAt.toUtc().toIso8601String(),
        o.updatedAt.toUtc().toIso8601String(),
        photos.map((p) => _fileName(p.filePath)).join(';'),
      ]);
    }
    return const ListToCsvConverter(eol: '\n').convert(rows);
  }

  static String buildTracks(Map<String, List<TrackPoint>> tracksByTrackId) {
    final rows = <List<Object?>>[
      ['track_id', 'lat', 'lon', 'altitude_m', 'accuracy_m', 'speed_mps', 'recorded_at_utc'],
    ];
    for (final entry in tracksByTrackId.entries) {
      for (final p in entry.value) {
        rows.add([
          entry.key,
          p.lat,
          p.lon,
          p.altitude,
          p.accuracy,
          p.speed,
          p.recordedAt.toUtc().toIso8601String(),
        ]);
      }
    }
    return const ListToCsvConverter(eol: '\n').convert(rows);
  }

  static String _fileName(String path) {
    final i = path.lastIndexOf(RegExp(r'[\\/]'));
    return i == -1 ? path : path.substring(i + 1);
  }
}
