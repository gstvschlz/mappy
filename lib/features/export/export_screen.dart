import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../projects/active_project.dart';
import 'zip_backup.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _busy = false;
  File? _lastFile;
  int? _lastBytes;
  String? _error;

  Future<void> _runBackup() async {
    final project = ref.read(activeProjectProvider).value;
    if (project == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(zipBackupProvider).backupProject(project);
      if (!mounted) return;
      setState(() {
        _lastFile = result.file;
        _lastBytes = result.bytes;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  Future<void> _share() async {
    final f = _lastFile;
    if (f == null) return;
    await Share.shareXFiles([XFile(f.path)],
        text: 'Mappy backup');
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeProjectProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Export & backup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              active == null
                  ? 'No active project.'
                  : 'Active project: ${active.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Backup creates a ZIP in your Downloads/Mappy folder containing '
              'observations.geojson, observations.csv, tracks.csv (if any), '
              'and all photo files.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (_busy || active == null) ? null : _runBackup,
              icon: const Icon(Icons.archive_outlined),
              label: Text(_busy ? 'Backing up...' : 'Backup now'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_lastFile != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last backup'),
                      const SizedBox(height: 4),
                      Text(_lastFile!.path,
                          style: const TextStyle(fontFamily: 'monospace')),
                      Text(
                        '${(_lastBytes! / (1024 * 1024)).toStringAsFixed(2)} MB',
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share),
                        label: const Text('Share ZIP'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
