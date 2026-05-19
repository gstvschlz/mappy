import 'dart:io';

import 'package:native_exif/native_exif.dart';

class ExifWriter {
  ExifWriter._();

  static Future<void> writeGeoTags(
    File jpeg, {
    required double lat,
    required double lon,
    double? altitude,
    double? bearing,
    DateTime? takenAt,
  }) async {
    Exif? exif;
    try {
      exif = await Exif.fromPath(jpeg.path);
      final attrs = <String, Object>{
        'GPSLatitude': lat,
        'GPSLongitude': lon,
        'GPSLatitudeRef': lat >= 0 ? 'N' : 'S',
        'GPSLongitudeRef': lon >= 0 ? 'E' : 'W',
      };
      if (altitude != null) {
        attrs['GPSAltitude'] = altitude.abs();
        attrs['GPSAltitudeRef'] = altitude >= 0 ? 0 : 1;
      }
      if (bearing != null) {
        attrs['GPSImgDirection'] = bearing;
        attrs['GPSImgDirectionRef'] = 'M'; // Magnetic north
      }
      if (takenAt != null) {
        final y = takenAt.year.toString().padLeft(4, '0');
        final mo = takenAt.month.toString().padLeft(2, '0');
        final d = takenAt.day.toString().padLeft(2, '0');
        final hh = takenAt.hour.toString().padLeft(2, '0');
        final mm = takenAt.minute.toString().padLeft(2, '0');
        final ss = takenAt.second.toString().padLeft(2, '0');
        attrs['DateTimeOriginal'] = '$y:$mo:$d $hh:$mm:$ss';
      }
      await exif.writeAttributes(attrs);
    } catch (_) {
      // Non-fatal: photo is still saved without EXIF if writer fails on a device.
    } finally {
      await exif?.close();
    }
  }
}
