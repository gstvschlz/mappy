import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of compass heading in degrees (0 = North). May emit null on devices
/// without a magnetometer.
final compassHeadingProvider = StreamProvider<double?>((ref) {
  final stream = FlutterCompass.events;
  if (stream == null) {
    return const Stream<double?>.empty();
  }
  return stream.map((e) => e.heading);
});
