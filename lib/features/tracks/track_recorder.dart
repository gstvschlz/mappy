import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';

const _kRecordingsPrefKey = 'mappy.activeRecordings';

/// A single in-progress track recording. There can be one per project,
/// running concurrently.
class Recording {
  const Recording({
    required this.projectId,
    required this.trackId,
    required this.startedAt,
  });

  final String projectId;
  final String trackId;
  final DateTime startedAt;

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'trackId': trackId,
        'startedAt': startedAt.toIso8601String(),
      };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        projectId: json['projectId'] as String,
        trackId: json['trackId'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
      );
}

/// Recorder state keyed by projectId. Multiple projects may record at once;
/// a single shared `Geolocator.getPositionStream` listener fans out each
/// position to every active project's track.
class TrackRecorderState {
  const TrackRecorderState({this.recordings = const {}});

  /// `projectId -> Recording`.
  final Map<String, Recording> recordings;

  bool isRecording(String projectId) => recordings.containsKey(projectId);

  Recording? recordingFor(String projectId) => recordings[projectId];

  bool get any => recordings.isNotEmpty;

  TrackRecorderState withRecording(Recording r) => TrackRecorderState(
        recordings: {...recordings, r.projectId: r},
      );

  TrackRecorderState withoutProject(String projectId) {
    final next = Map<String, Recording>.from(recordings)..remove(projectId);
    return TrackRecorderState(recordings: next);
  }
}

class TrackRecorder extends StateNotifier<TrackRecorderState> {
  TrackRecorder(this._db) : super(const TrackRecorderState()) {
    _restore();
  }

  final AppDatabase _db;
  StreamSubscription<Position>? _sub;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecordingsPrefKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(Recording.fromJson)
          .toList();
      if (list.isEmpty) return;
      // Validate against current DB — drop entries whose project has been
      // deleted, otherwise foreign-key inserts would fail.
      final validated = <Recording>[];
      for (final r in list) {
        final project = await _db.projectDao.getById(r.projectId);
        if (project != null) validated.add(r);
      }
      if (validated.isEmpty) {
        await prefs.remove(_kRecordingsPrefKey);
        return;
      }
      state = TrackRecorderState(
        recordings: {for (final r in validated) r.projectId: r},
      );
      await _restartSubscription();
    } catch (_) {
      await prefs.remove(_kRecordingsPrefKey);
    }
  }

  Future<void> start(String projectId) async {
    if (state.isRecording(projectId)) return;
    final recording = Recording(
      projectId: projectId,
      trackId: const Uuid().v4(),
      startedAt: DateTime.now(),
    );
    state = state.withRecording(recording);
    await _persist();
    await _restartSubscription();
  }

  Future<void> stop(String projectId) async {
    if (!state.isRecording(projectId)) return;
    state = state.withoutProject(projectId);
    await _persist();
    if (state.any) {
      await _restartSubscription();
    } else {
      await _sub?.cancel();
      _sub = null;
    }
  }

  Future<void> stopAll() async {
    if (!state.any) return;
    state = const TrackRecorderState();
    await _persist();
    await _sub?.cancel();
    _sub = null;
  }

  /// (Re)subscribes to the GPS stream, regenerating the foreground
  /// notification text to reflect the currently recording projects.
  Future<void> _restartSubscription() async {
    await _sub?.cancel();
    _sub = null;
    if (!state.any) return;

    final notificationText = await _notificationText();

    _sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Mappy — recording',
          notificationText: notificationText,
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
    ).listen(_onPosition);
  }

  Future<String> _notificationText() async {
    final recordings = state.recordings.values.toList();
    if (recordings.length == 1) {
      final project = await _db.projectDao.getById(recordings.first.projectId);
      return project == null
          ? 'GPS track recording in progress'
          : 'Recording ${project.name}';
    }
    return 'Recording ${recordings.length} projects';
  }

  Future<void> _onPosition(Position pos) async {
    // Snapshot to avoid mutation during iteration.
    final active = List<Recording>.from(state.recordings.values);
    if (active.isEmpty) return;
    final now = DateTime.now();
    for (final r in active) {
      await _db.trackDao.insertPoint(
        TrackPointsCompanion(
          projectId: Value(r.projectId),
          trackId: Value(r.trackId),
          lat: Value(pos.latitude),
          lon: Value(pos.longitude),
          altitude: Value(pos.altitude),
          accuracy: Value(pos.accuracy),
          speed: Value(pos.speed),
          recordedAt: Value(now),
        ),
      );
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list =
        state.recordings.values.map((r) => r.toJson()).toList();
    if (list.isEmpty) {
      await prefs.remove(_kRecordingsPrefKey);
    } else {
      await prefs.setString(_kRecordingsPrefKey, jsonEncode(list));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final trackRecorderProvider =
    StateNotifierProvider<TrackRecorder, TrackRecorderState>((ref) {
  return TrackRecorder(ref.watch(appDatabaseProvider));
});
