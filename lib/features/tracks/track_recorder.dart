import 'package:drift/drift.dart' show Value;
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  TrackRecorderState copyWith({
    bool? isRecording,
    String? activeTrackId,
    String? activeProjectId,
  }) =>
      TrackRecorderState(
        isRecording: isRecording ?? this.isRecording,
        activeTrackId: activeTrackId,
        activeProjectId: activeProjectId,
      );
}

class TrackRecorder extends StateNotifier<TrackRecorderState> {
  TrackRecorder(this._db) : super(TrackRecorderState.idle) {
    _wire();
  }

  final AppDatabase _db;
  bool _configured = false;

  Future<void> _wire() async {
    bg.BackgroundGeolocation.onLocation((bg.Location loc) async {
      final trackId = state.activeTrackId;
      final projectId = state.activeProjectId;
      if (trackId == null || projectId == null) return;
      await _db.trackDao.insertPoint(
        TrackPointsCompanion(
          projectId: Value(projectId),
          trackId: Value(trackId),
          lat: Value(loc.coords.latitude),
          lon: Value(loc.coords.longitude),
          altitude: Value(loc.coords.altitude),
          accuracy: Value(loc.coords.accuracy),
          speed: Value(loc.coords.speed),
          recordedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> _configure() async {
    if (_configured) return;
    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 5.0,
      stopOnTerminate: false,
      startOnBoot: false,
      enableHeadless: false,
      notification: bg.Notification(
        title: 'Mappy — recording track',
        text: 'GPS track recording in progress',
        sticky: true,
      ),
      debug: false,
      logLevel: bg.Config.LOG_LEVEL_ERROR,
    ));
    _configured = true;
  }

  Future<void> start(String projectId) async {
    await _configure();
    final trackId = const Uuid().v4();
    state = TrackRecorderState(
      isRecording: true,
      activeTrackId: trackId,
      activeProjectId: projectId,
    );
    await bg.BackgroundGeolocation.start();
  }

  Future<void> stop() async {
    await bg.BackgroundGeolocation.stop();
    state = TrackRecorderState.idle;
  }
}

final trackRecorderProvider =
    StateNotifierProvider<TrackRecorder, TrackRecorderState>((ref) {
  return TrackRecorder(ref.watch(appDatabaseProvider));
});
