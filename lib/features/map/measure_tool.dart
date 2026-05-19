import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class MeasureMode {
  final List<LatLng> points = [];
  final Distance _distance = const Distance();

  void addPoint(LatLng p) => points.add(p);
  void removeLast() {
    if (points.isNotEmpty) points.removeLast();
  }

  double totalDistanceMeters() {
    if (points.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += _distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return sum;
  }

  /// Polygon area using spherical excess (good enough for field measurements).
  /// Result in square meters. Assumes points form a closed ring (first==last
  /// is not required — algorithm closes implicitly).
  double polygonAreaSqMeters() {
    if (points.length < 3) return 0;
    const double earthRadius = 6378137.0;
    double total = 0;
    for (var i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      total += _toRad(p2.longitude - p1.longitude) *
          (2 + math.sin(_toRad(p1.latitude)) + math.sin(_toRad(p2.latitude)));
    }
    return (total.abs() * earthRadius * earthRadius / 2);
  }

  String summary() {
    final dist = totalDistanceMeters();
    final distStr = dist >= 1000
        ? '${(dist / 1000).toStringAsFixed(2)} km'
        : '${dist.toStringAsFixed(0)} m';
    if (points.length < 3) {
      return 'Distance: $distStr (${points.length} pts)';
    }
    final area = polygonAreaSqMeters();
    final areaStr = area >= 10000
        ? '${(area / 10000).toStringAsFixed(2)} ha'
        : '${area.toStringAsFixed(0)} m²';
    return 'Distance: $distStr · Area: $areaStr (${points.length} pts)';
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;
}
