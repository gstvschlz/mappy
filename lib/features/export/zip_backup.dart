import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import '../../core/files/paths.dart';
import 'csv_export.dart';
import 'geojson_export.dart';

class BackupResult {
  const BackupResult({required this.file, required this.bytes});
  final File file;
  final int bytes;
}

class ZipBackup {
  ZipBackup(this._db);
  final AppDatabase _db;

  Future<BackupResult> backupProject(Project project) async {
    final obs = await _db.observationDao.activeForProject(project.id);
    final photosByObs = <String, List<Photo>>{};
    for (final o in obs) {
      photosByObs[o.id] = await _db.photoDao.forObservation(o.id);
    }
    final trackIds = await _db.trackDao.distinctTrackIds(project.id);
    final tracks = <String, List<TrackPoint>>{};
    for (final id in trackIds) {
      tracks[id] = await _db.trackDao.forTrack(id);
    }

    final archive = Archive();

    final geojson =
        GeoJsonExport.build(
      project: project,
      observations: obs,
      photosByObservation: photosByObs,
      tracksByTrackId: tracks,
    );
    archive.addFile(_textFile('observations.geojson', geojson));

    final csv = CsvExport.buildObservations(
      observations: obs,
      photosByObservation: photosByObs,
    );
    archive.addFile(_textFile('observations.csv', csv));

    if (tracks.isNotEmpty) {
      final trackCsv = CsvExport.buildTracks(tracks);
      archive.addFile(_textFile('tracks.csv', trackCsv));
    }

    // Photos
    for (final entry in photosByObs.entries) {
      for (final photo in entry.value) {
        final file = File(photo.filePath);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        archive.addFile(
          ArchiveFile(
            'photos/${entry.key}/${p.basename(photo.filePath)}',
            bytes.length,
            bytes,
          ),
        );
      }
    }

    final encoded = ZipEncoder().encode(archive)!;
    final downloads = await AppPaths.downloadsDir();
    final ts = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final safeName = project.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final outFile = File(p.join(downloads.path, 'mappy_${safeName}_$ts.zip'));
    await outFile.writeAsBytes(Uint8List.fromList(encoded));
    return BackupResult(file: outFile, bytes: encoded.length);
  }

  ArchiveFile _textFile(String name, String contents) {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    return ArchiveFile(name, bytes.length, bytes);
  }
}

final zipBackupProvider = Provider<ZipBackup>((ref) {
  return ZipBackup(ref.watch(appDatabaseProvider));
});
