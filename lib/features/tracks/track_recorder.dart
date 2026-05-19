import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';

class TrackRecorderState {
  const TrackRecorderState({
    required this.isRecording,
    required this.activeTrackId,
    required this.activeProjectId,
  });

  final bool isRecording;
  final String? activeTrackId;
  final String? activeProjectId;

  static const idle = TrackRecorderState(
    isRecording: false,
    activeTrackId: null,
    activeProjectId: null,
  );
}

class TrackRecorder extends StateNotifier<TrackRecorderState> {
  TrackRecorder(this._db) : super(TrackRecorderState.idle);

  final AppDatabase _db;
  StreamSubscription<Position>? _sub;

  Future<void> start(String projectId) async {
    if (state.isRecording) return;
    final trackId = const Uuid().v4();
    state = TrackRecorderState(
      isRecording: true,
      activeTrackId: trackId,
      activeProjectId: projectId,
    );
    _sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Mappy — recording track',
          notificationText: 'GPS track recording in progress',
          enableWakeLock: true,
        ),
      ),
    ).listen((pos) async {
      final tid = state.activeTrackId;
      final pid = state.activeProjectId;
      if (tid == null || pid == null) return;
      await _db.trackDao.insertPoint(
        TrackPointsCompanion(
          projectId: Value(pid),
          trackId: Value(tid),
          lat: Value(pos.latitude),
          lon: Value(pos.longitude),
          altitude: Value(pos.altitude),
          accuracy: Value(pos.accuracy),
          speed: Value(pos.speed),
          recordedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    state = TrackRecorderState.idle;
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
