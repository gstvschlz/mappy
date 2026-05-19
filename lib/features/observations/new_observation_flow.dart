import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import '../../core/files/paths.dart';
import '../../core/location/location_service.dart';
import '../projects/active_project.dart';
import 'observation_camera.dart';

class NewObservationFlow extends ConsumerStatefulWidget {
  const NewObservationFlow({super.key, this.manualPoint});

  final LatLng? manualPoint;

  @override
  ConsumerState<NewObservationFlow> createState() =>
      _NewObservationFlowState();
}

class _NewObservationFlowState extends ConsumerState<NewObservationFlow> {
  final TextEditingController _descController = TextEditingController();
  List<CapturedShot> _shots = [];
  Position? _fix;
  bool _loadingFix = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resolveFix();
  }

  Future<void> _resolveFix() async {
    if (widget.manualPoint != null) {
      setState(() => _loadingFix = false);
      return;
    }
    final svc = ref.read(locationServiceProvider);
    final pos = await svc.currentFix();
    if (!mounted) return;
    setState(() {
      _fix = pos;
      _loadingFix = false;
    });
  }

  Future<void> _pickPhotos() async {
    final shots = await Navigator.of(context).push<List<CapturedShot>>(
      MaterialPageRoute(builder: (_) => const ObservationCamera()),
    );
    if (shots != null) {
      setState(() => _shots = shots);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final active = ref.read(activeProjectProvider).value;
    if (active == null) return;

    final hasManual = widget.manualPoint != null;
    final lat = hasManual ? widget.manualPoint!.latitude : _fix?.latitude;
    final lon = hasManual ? widget.manualPoint!.longitude : _fix?.longitude;
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No GPS fix yet — wait a moment.')),
      );
      return;
    }

    setState(() => _saving = true);

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final obsId = const Uuid().v4();

    final observation = Observation(
      id: obsId,
      projectId: active.id,
      description: _descController.text.trim(),
      lat: lat,
      lon: lon,
      altitude: hasManual ? null : _fix?.altitude,
      accuracy: hasManual ? null : _fix?.accuracy,
      manualPlacement: hasManual,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await db.observationDao.insert(observation);

    // Move photos from temp into the persistent folder.
    final dir = await AppPaths.photosDir(obsId);
    for (var i = 0; i < _shots.length; i++) {
      final shot = _shots[i];
      final fileName = '${const Uuid().v4()}.jpg';
      final target = File(p.join(dir.path, fileName));
      await shot.file.rename(target.path).catchError((_) async {
        // rename fails across volumes; copy instead.
        await target.writeAsBytes(await shot.file.readAsBytes());
        await shot.file.delete();
        return target;
      });
      await db.photoDao.insert(Photo(
        id: const Uuid().v4(),
        observationId: obsId,
        filePath: target.path,
        bearing: shot.bearing,
        altitude: shot.altitude,
        takenAt: shot.takenAt,
        sortIndex: i,
      ));
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasManual = widget.manualPoint != null;
    final lat = hasManual ? widget.manualPoint!.latitude : _fix?.latitude;
    final lon = hasManual ? widget.manualPoint!.longitude : _fix?.longitude;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New observation'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    hasManual ? Icons.touch_app : Icons.gps_fixed,
                    color: hasManual
                        ? Theme.of(context).colorScheme.tertiary
                        : (lat == null
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _loadingFix
                        ? const Text('Getting GPS fix...')
                        : Text(
                            lat == null
                                ? 'No location'
                                : '${lat.toStringAsFixed(6)}, '
                                    '${lon!.toStringAsFixed(6)}'
                                    '${hasManual ? ' (manual)' : (_fix?.accuracy.isFinite ?? false ? ' ±${_fix!.accuracy.toStringAsFixed(0)} m' : '')}',
                          ),
                  ),
                  if (!hasManual)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        setState(() => _loadingFix = true);
                        _resolveFix();
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickPhotos,
            icon: const Icon(Icons.add_a_photo),
            label: Text(_shots.isEmpty
                ? 'Take photos'
                : 'Photos (${_shots.length}) — re-take'),
          ),
          if (_shots.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _shots.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(_shots[i].file,
                        width: 80, height: 80, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 6,
            minLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText:
                  'e.g. Pale-blue chalcedony nodule in basalt, 5 cm wide.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
