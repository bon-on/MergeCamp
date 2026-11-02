import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'camp_progress.dart';

/// Persists [CampProgress] as a JSON string under [progressKey].
///
/// Storage failures never break play: a read failure or corrupt value loads
/// the initial progress and a write failure is ignored. Tests use
/// [MemoryCampProgressStore].
class CampProgressStore {
  const CampProgressStore();

  static const String progressKey = 'camp_progress_v1';

  Future<CampProgress> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(progressKey);
      if (raw == null) return const CampProgress.initial();
      return CampProgress.fromJson(jsonDecode(raw));
    } catch (_) {
      return const CampProgress.initial();
    }
  }

  Future<void> save(CampProgress progress) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(progressKey, jsonEncode(progress.toJson()));
    } catch (_) {
      return;
    }
  }
}

/// In-memory store for tests.
class MemoryCampProgressStore extends CampProgressStore {
  MemoryCampProgressStore([this.value = const CampProgress.initial()]);

  CampProgress value;
  int saveCount = 0;

  @override
  Future<CampProgress> load() async => value;

  @override
  Future<void> save(CampProgress progress) async {
    value = progress;
    saveCount += 1;
  }
}
