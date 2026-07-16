/// Practice statistics (#133) computed from the metronome's session log —
/// the Hive box the metronome has been writing since sessions shipped
/// (`metronome_sessions_v1`), read here for the first time.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/metronome_session.dart';
import '../repositories/metronome_session_repository.dart';

class PracticeStats {
  const PracticeStats({
    required this.totalSecondsThisWeek,
    required this.sessionCountThisWeek,
    required this.streakDays,
    required this.dailySeconds,
    required this.perSongSeconds,
    this.lastSession,
  });

  static const empty = PracticeStats(
    totalSecondsThisWeek: 0,
    sessionCountThisWeek: 0,
    streakDays: 0,
    dailySeconds: [0, 0, 0, 0, 0, 0, 0],
    perSongSeconds: {},
  );

  final int totalSecondsThisWeek;
  final int sessionCountThisWeek;

  /// Consecutive practice days ending today or yesterday.
  final int streakDays;

  /// Seconds per day for the last 7 days, oldest → today (length 7).
  final List<int> dailySeconds;

  /// This week's seconds per songId ('' key = freestyle, no song loaded).
  final Map<String, int> perSongSeconds;
  final MetronomeSession? lastSession;

  bool get isEmptyWeek => totalSecondsThisWeek == 0;
}

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// Pure bucketing — session counts on its local start date; zero-length
/// sessions are noise (instant stops) and are ignored.
PracticeStats computePracticeStats(
  List<MetronomeSession> sessions,
  DateTime now,
) {
  final today = _dateOnly(now);
  final weekStart = today.subtract(const Duration(days: 6));

  final real = sessions.where((s) => s.elapsedSeconds > 0).toList();

  final daily = List<int>.filled(7, 0);
  final perSong = <String, int>{};
  var total = 0;
  var count = 0;
  final practiceDays = <DateTime>{};

  for (final s in real) {
    final day = _dateOnly(s.startedAt);
    practiceDays.add(day);
    final offset = day.difference(weekStart).inDays;
    if (offset < 0 || offset > 6) continue;
    daily[offset] += s.elapsedSeconds;
    total += s.elapsedSeconds;
    count++;
    perSong.update(
      s.songId ?? '',
      (v) => v + s.elapsedSeconds,
      ifAbsent: () => s.elapsedSeconds,
    );
  }

  // Streak: walk back from today; a streak that ended yesterday still counts
  // (you haven't broken it until today passes without practice).
  var streak = 0;
  var cursor = practiceDays.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));
  while (practiceDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return PracticeStats(
    totalSecondsThisWeek: total,
    sessionCountThisWeek: count,
    streakDays: streak,
    dailySeconds: daily,
    perSongSeconds: perSong,
    lastSession: real.isEmpty ? null : real.first,
  );
}

final metronomeSessionRepositoryProvider =
    Provider<MetronomeSessionRepository>((ref) => MetronomeSessionRepository());

final practiceStatsProvider = FutureProvider.autoDispose<PracticeStats>((
  ref,
) async {
  if (!MetronomeSessionRepository.storageReady) return PracticeStats.empty;
  final sessions = await ref
      .watch(metronomeSessionRepositoryProvider)
      .listAll();
  return computePracticeStats(sessions, DateTime.now());
});

/// All sessions, newest first — the Practice screen's logbook.
final practiceSessionsProvider = FutureProvider.autoDispose<
  List<MetronomeSession>
>((ref) async {
  if (!MetronomeSessionRepository.storageReady) return const [];
  final sessions = await ref
      .watch(metronomeSessionRepositoryProvider)
      .listAll();
  return sessions.where((s) => s.elapsedSeconds > 0).toList();
});
