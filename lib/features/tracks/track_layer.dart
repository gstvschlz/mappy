import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';

final trackPointsForProjectProvider =
    StreamProvider.family<List<TrackPoint>, String>((ref, projectId) {
  return ref.watch(appDatabaseProvider).trackDao.watchForProject(projectId);
});

class TrackLayer extends ConsumerWidget {
  const TrackLayer({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPoints = ref.watch(trackPointsForProjectProvider(projectId));
    return asyncPoints.maybeWhen(
      data: (points) {
        if (points.length < 2) return const SizedBox.shrink();

        // Group consecutive points by trackId so different tracks render as
        // separate polylines.
        final byTrack = <String, List<LatLng>>{};
        for (final p in points) {
          byTrack.putIfAbsent(p.trackId, () => []).add(LatLng(p.lat, p.lon));
        }
        return PolylineLayer(
          polylines: byTrack.values
              .map((pts) => Polyline(
                    points: pts,
                    strokeWidth: 3,
                    color: Theme.of(context).colorScheme.secondary,
                  ))
              .toList(),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
