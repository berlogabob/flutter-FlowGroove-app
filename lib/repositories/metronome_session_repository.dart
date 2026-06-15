import 'package:hive/hive.dart';

import '../models/metronome_session.dart';

class MetronomeSessionRepository {
  static const String boxName = 'metronome_sessions_v1';
  static bool storageReady = false;

  Future<Box<dynamic>> get _box => Hive.openBox<dynamic>(boxName);

  Future<void> save(MetronomeSession session) async {
    await (await _box).put(session.id, session.toJson());
  }

  Future<List<MetronomeSession>> listForSong(String songId) async {
    final sessions = await listAll();
    return sessions.where((session) => session.songId == songId).toList();
  }

  Future<List<MetronomeSession>> listAll() async {
    final box = await _box;
    final sessions = box.values
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (value) =>
              MetronomeSession.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<MetronomeSessionSummary> summarize(String songId) async {
    final sessions = await listForSong(songId);
    return MetronomeSessionSummary(
      sessionCount: sessions.length,
      totalSeconds: sessions.fold(0, (sum, item) => sum + item.elapsedSeconds),
      lastPracticedAt: sessions.isEmpty ? null : sessions.first.endedAt,
      latestBpm: sessions.isEmpty ? null : sessions.first.endBpm,
    );
  }
}
