import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';

const _kActiveProjectKey = 'mappy.activeProjectId';

class ActiveProjectController extends StateNotifier<AsyncValue<Project?>> {
  ActiveProjectController(this._db) : super(const AsyncValue.loading()) {
    _load();
  }

  final AppDatabase _db;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kActiveProjectKey);
    if (id == null) {
      // Auto-pick the most recent project if any exists.
      final all = await _db.projectDao.getAll();
      if (all.isNotEmpty) {
        await _persist(all.first.id);
        state = AsyncValue.data(all.first);
      } else {
        state = const AsyncValue.data(null);
      }
      return;
    }
    final project = await _db.projectDao.getById(id);
    if (project == null) {
      final all = await _db.projectDao.getAll();
      final fallback = all.isEmpty ? null : all.first;
      if (fallback != null) {
        await _persist(fallback.id);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kActiveProjectKey);
      }
      state = AsyncValue.data(fallback);
    } else {
      state = AsyncValue.data(project);
    }
  }

  Future<void> setActive(String projectId) async {
    final project = await _db.projectDao.getById(projectId);
    if (project == null) return;
    await _persist(projectId);
    state = AsyncValue.data(project);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActiveProjectKey);
    state = const AsyncValue.data(null);
  }

  Future<void> _persist(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveProjectKey, id);
  }
}

final activeProjectProvider =
    StateNotifierProvider<ActiveProjectController, AsyncValue<Project?>>((ref) {
  return ActiveProjectController(ref.watch(appDatabaseProvider));
});

final allProjectsStreamProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(appDatabaseProvider).projectDao.watchAll();
});
