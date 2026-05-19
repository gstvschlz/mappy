import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mappy/core/db/database.dart';
import 'package:mappy/features/export/geojson_export.dart';

void main() {
  test('builds a valid FeatureCollection with point + linestring', () {
    final now = DateTime.utc(2026, 5, 19, 12);
    final project = Project(
      id: 'p',
      name: "Mother's Farm",
      createdAt: now,
    );
    final obs = [
      Observation(
        id: 'o1',
        projectId: 'p',
        description: 'Pale-blue chalcedony',
        lat: -29.5,
        lon: -53.5,
        altitude: 320.0,
        accuracy: 5.0,
        manualPlacement: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      ),
    ];
    final photos = {
      'o1': [
        Photo(
          id: 'ph1',
          observationId: 'o1',
          filePath: '/tmp/photos/o1/abc.jpg',
          bearing: 88.5,
          altitude: 320.0,
          takenAt: now,
          sortIndex: 0,
        ),
      ],
    };
    final tracks = {
      't1': [
        TrackPoint(
          id: 1,
          projectId: 'p',
          trackId: 't1',
          lat: -29.5,
          lon: -53.5,
          altitude: 320,
          accuracy: 5,
          speed: 1.2,
          recordedAt: now,
        ),
        TrackPoint(
          id: 2,
          projectId: 'p',
          trackId: 't1',
          lat: -29.501,
          lon: -53.501,
          altitude: 322,
          accuracy: 5,
          speed: 1.1,
          recordedAt: now.add(const Duration(seconds: 10)),
        ),
      ],
    };

    final raw = GeoJsonExport.build(
      project: project,
      observations: obs,
      photosByObservation: photos,
      tracksByTrackId: tracks,
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['type'], 'FeatureCollection');
    expect(decoded['name'], "Mother's Farm");
    final features = decoded['features'] as List;
    expect(features.length, 2);

    final point = features[0] as Map<String, dynamic>;
    expect(point['geometry']['type'], 'Point');
    expect(point['geometry']['coordinates'], [-53.5, -29.5, 320.0]);
    final photoEntries =
        (point['properties']['photos'] as List).cast<Map<String, dynamic>>();
    expect(photoEntries.first['file'], 'abc.jpg');
    expect(photoEntries.first['bearing'], 88.5);

    final line = features[1] as Map<String, dynamic>;
    expect(line['geometry']['type'], 'LineString');
    expect((line['geometry']['coordinates'] as List).length, 2);
  });

  test('omits tracks with fewer than 2 points', () {
    final now = DateTime.utc(2026, 5, 19);
    final raw = GeoJsonExport.build(
      project: Project(id: 'p', name: 'P', createdAt: now),
      observations: const [],
      photosByObservation: const {},
      tracksByTrackId: {
        't1': [
          TrackPoint(
            id: 1,
            projectId: 'p',
            trackId: 't1',
            lat: 0,
            lon: 0,
            altitude: null,
            accuracy: null,
            speed: null,
            recordedAt: now,
          ),
        ],
      },
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect((decoded['features'] as List), isEmpty);
  });
}
