import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mappy/features/map/measure_tool.dart';

void main() {
  test('distance over a 1 km segment is ~1000 m', () {
    final m = MeasureMode();
    m.addPoint(const LatLng(-29.5, -53.5));
    // ~1 km east at this latitude
    m.addPoint(const LatLng(-29.5, -53.4897));
    final d = m.totalDistanceMeters();
    expect(d, inInclusiveRange(900, 1100));
  });

  test('polygon area is approximately right', () {
    final m = MeasureMode();
    // ~111 km x 111 km square = ~12,321 km² near the equator.
    // Use small box to keep it tractable.
    m.addPoint(const LatLng(0, 0));
    m.addPoint(const LatLng(0, 0.01));
    m.addPoint(const LatLng(0.01, 0.01));
    m.addPoint(const LatLng(0.01, 0));
    final area = m.polygonAreaSqMeters();
    // 0.01° ≈ 1.11 km on the equator -> area ≈ 1,234,000 m²
    expect(area, inInclusiveRange(1.0e6, 1.5e6));
  });
}
