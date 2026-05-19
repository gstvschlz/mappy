import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a permissions pass.
class PermissionsState {
  const PermissionsState({
    required this.camera,
    required this.locationWhenInUse,
    required this.locationAlways,
    required this.storage,
    required this.notifications,
  });

  final bool camera;
  final bool locationWhenInUse;
  final bool locationAlways;
  final bool storage;
  final bool notifications;

  bool get minimumViable => camera && locationWhenInUse;
  bool get trackingViable => minimumViable && locationAlways && notifications;
}

class PermissionsGate {
  PermissionsGate._();

  static Future<PermissionsState> request() async {
    final camera = await Permission.camera.request();
    final whenInUse = await Permission.locationWhenInUse.request();
    final notifications = await Permission.notification.request();
    final always = whenInUse.isGranted
        ? await Permission.locationAlways.request()
        : PermissionStatus.denied;
    final storage = await Permission.storage.request();

    return PermissionsState(
      camera: camera.isGranted,
      locationWhenInUse: whenInUse.isGranted,
      locationAlways: always.isGranted,
      storage: storage.isGranted || storage.isLimited,
      notifications: notifications.isGranted,
    );
  }

  static Future<PermissionsState> check() async {
    final camera = await Permission.camera.status;
    final whenInUse = await Permission.locationWhenInUse.status;
    final always = await Permission.locationAlways.status;
    final storage = await Permission.storage.status;
    final notifications = await Permission.notification.status;

    return PermissionsState(
      camera: camera.isGranted,
      locationWhenInUse: whenInUse.isGranted,
      locationAlways: always.isGranted,
      storage: storage.isGranted || storage.isLimited,
      notifications: notifications.isGranted,
    );
  }
}

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  PermissionsState? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await PermissionsGate.check();
    if (!mounted) return;
    setState(() => _state = s);
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    final s = await PermissionsGate.request();
    if (!mounted) return;
    setState(() {
      _state = s;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Mappy needs a few permissions to map your observations.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (s != null) ...[
              _row('Camera', s.camera, required: true),
              _row('Location (while using app)', s.locationWhenInUse,
                  required: true),
              _row('Location (always, for track recording)', s.locationAlways),
              _row('Notifications (track recording status)', s.notifications),
              _row('Storage (for exports)', s.storage),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _request,
              child: Text(_busy ? 'Requesting...' : 'Grant permissions'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: openAppSettings,
              child: const Text('Open app settings'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: (s?.minimumViable ?? false) ? widget.onContinue : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, bool granted, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: granted
                ? Colors.green
                : (required ? Colors.red : Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (required && !granted)
            const Text('required', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
