import 'package:flutter_test/flutter_test.dart';
import 'package:mappy/core/db/database.dart';
import 'package:mappy/features/export/csv_export.dart';

void main() {
  test('observation CSV header + row', () {
    final now = DateTime.utc(2026, 5, 19, 12);
    final csv = CsvExport.buildObservations(
      observations: [
        Observation(
          id: 'o1',
          projectId: 'p',
          description: 'note with, comma and\nnewline',
          lat: -29.5,
          lon: -53.5,
          altitude: 100.0,
          accuracy: 4.0,
          manualPlacement: true,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        ),
      ],
      photosByObservation: {
        'o1': [
          Photo(
            id: 'ph1',
            observationId: 'o1',
            filePath: '/x/o1/a.jpg',
            bearing: null,
            altitude: null,
            takenAt: now,
            sortIndex: 0,
          ),
        ],
      },
    );
    final lines = csv.split('\n');
    expect(lines.first.startsWith('id,description'), isTrue);
    expect(lines[1], contains('o1'));
    expect(lines[1], contains('a.jpg'));
    expect(lines[1], contains('\\n')); // newline escaped, not literal break
  });

  test('tracks CSV produces one row per point', () {
    final now = DateTime.utc(2026, 5, 19, 12);
    final csv = CsvExport.buildTracks({
      't1': [
        TrackPoint(
          id: 1,
          projectId: 'p',
          trackId: 't1',
          lat: 1,
          lon: 2,
          altitude: 3,
          accuracy: 4,
          speed: 5,
          recordedAt: now,
        ),
        TrackPoint(
          id: 2,
          projectId: 'p',
          trackId: 't1',
          lat: 1.1,
          lon: 2.1,
          altitude: null,
          accuracy: null,
          speed: null,
          recordedAt: now.add(const Duration(seconds: 5)),
        ),
      ],
    });
    final lines = csv.trim().split('\n');
    expect(lines.length, 3); // header + 2 points
  });
}
