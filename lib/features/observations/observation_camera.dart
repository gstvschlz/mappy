import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/exif/exif_writer.dart';

class CapturedShot {
  CapturedShot({
    required this.file,
    required this.takenAt,
    this.bearing,
    this.altitude,
    this.lat,
    this.lon,
  });

  final File file;
  final DateTime takenAt;
  final double? bearing;
  final double? altitude;
  final double? lat;
  final double? lon;
}

class ObservationCamera extends StatefulWidget {
  const ObservationCamera({super.key});

  @override
  State<ObservationCamera> createState() => _ObservationCameraState();
}

class _ObservationCameraState extends State<ObservationCamera> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  final List<CapturedShot> _shots = [];
  double? _heading;
  bool _showScaleHint = true;
  bool _busy = false;
  String? _error;
  StreamSubscription<CompassEvent>? _compassSub;

  @override
  void initState() {
    super.initState();
    _setup();
    _compassSub = FlutterCompass.events?.listen((e) {
      if (mounted) setState(() => _heading = e.heading);
    });
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final raw = await controller.takePicture();
      final now = DateTime.now();

      Position? fix;
      try {
        fix = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        fix = await Geolocator.getLastKnownPosition();
      }

      final tmpDir = await getTemporaryDirectory();
      final outPath = p.join(tmpDir.path, '${const Uuid().v4()}.jpg');
      final compressed = await FlutterImageCompress.compressAndGetFile(
        raw.path,
        outPath,
        quality: 85,
        minWidth: 1600,
        minHeight: 1600,
        keepExif: true,
      );
      final outFile = File(compressed?.path ?? raw.path);

      if (fix != null) {
        await ExifWriter.writeGeoTags(
          outFile,
          lat: fix.latitude,
          lon: fix.longitude,
          altitude: fix.altitude,
          bearing: _heading,
          takenAt: now,
        );
      }

      setState(() {
        _shots.add(CapturedShot(
          file: outFile,
          takenAt: now,
          bearing: _heading,
          altitude: fix?.altitude,
          lat: fix?.latitude,
          lon: fix?.longitude,
        ));
        _showScaleHint = false;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  void _finish() => Navigator.of(context).pop(_shots);

  void _removeShot(int i) {
    final s = _shots.removeAt(i);
    s.file.deleteSync();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Photos (${_shots.length})'),
        actions: [
          TextButton(
            onPressed: _shots.isEmpty ? null : _finish,
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
          : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(controller),
                          if (_showScaleHint)
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 16,
                              child: Material(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    'Tip: include a coin or your hammer for scale.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          if (_heading != null)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_heading!.toStringAsFixed(0)}°',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_shots.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: _shots.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    _shots[i].file,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: IconButton(
                                    iconSize: 20,
                                    icon: const Icon(Icons.cancel,
                                        color: Colors.white),
                                    onPressed: () => _removeShot(i),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Spacer(),
                          GestureDetector(
                            onTap: _capture,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                                color: _busy ? Colors.grey : Colors.white,
                              ),
                              child: _busy
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : null,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
