import 'package:flowgroove/models/metronome_session.dart';
import 'package:flowgroove/providers/practice_stats_provider.dart';
import 'package:flutter_test/flutter_test.dart';

MetronomeSession _s(
  DateTime startedAt, {
  int seconds = 600,
  String? songId,
}) => MetronomeSession(
  id: '${startedAt.toIso8601String()}-$seconds',
  startedAt: startedAt,
  startBpm: 100,
  elapsedSeconds: seconds,
  songId: songId,
);

void main() {
  // Wednesday 2026-07-15, 18:00 local.
  final now = DateTime(2026, 7, 15, 18);

  group('computePracticeStats (#133)', () {
    test('empty log yields the empty stats', () {
      final stats = computePracticeStats(const [], now);
      expect(stats.totalSecondsThisWeek, 0);
      expect(stats.streakDays, 0);
      expect(stats.dailySeconds, everyElement(0));
      expect(stats.isEmptyWeek, isTrue);
    });

    test('buckets sessions per day, oldest→today', () {
      final stats = computePracticeStats([
        _s(DateTime(2026, 7, 15, 9), seconds: 300), // today → index 6
        _s(DateTime(2026, 7, 14, 22), seconds: 600), // yesterday → index 5
        _s(DateTime(2026, 7, 9, 8), seconds: 120), // 6 days ago → index 0
        _s(DateTime(2026, 7, 8, 8), seconds: 999), // 7 days ago → outside
      ], now);

      expect(stats.dailySeconds[6], 300);
      expect(stats.dailySeconds[5], 600);
      expect(stats.dailySeconds[0], 120);
      expect(stats.totalSecondsThisWeek, 300 + 600 + 120);
      expect(stats.sessionCountThisWeek, 3);
    });

    test('streak counts consecutive days ending today', () {
      final stats = computePracticeStats([
        _s(DateTime(2026, 7, 15, 9)),
        _s(DateTime(2026, 7, 14, 9)),
        _s(DateTime(2026, 7, 13, 9)),
        _s(DateTime(2026, 7, 11, 9)), // gap on the 12th breaks it
      ], now);
      expect(stats.streakDays, 3);
    });

    test('streak survives a not-yet-practiced today (ends yesterday)', () {
      final stats = computePracticeStats([
        _s(DateTime(2026, 7, 14, 9)),
        _s(DateTime(2026, 7, 13, 9)),
      ], now);
      expect(stats.streakDays, 2);
    });

    test('streak is 0 when last practice was 2+ days ago', () {
      final stats = computePracticeStats([
        _s(DateTime(2026, 7, 12, 9)),
      ], now);
      expect(stats.streakDays, 0);
    });

    test('zero-length sessions are ignored everywhere', () {
      final stats = computePracticeStats([
        _s(DateTime(2026, 7, 15, 9), seconds: 0),
      ], now);
      expect(stats.totalSecondsThisWeek, 0);
      expect(stats.streakDays, 0);
    });

    test('per-song split with freestyle fallback', () {
      final stats = computePracticeStats([
        _s(DateTime(2026, 7, 15, 9), seconds: 300, songId: 'song-a'),
        _s(DateTime(2026, 7, 14, 9), seconds: 200, songId: 'song-a'),
        _s(DateTime(2026, 7, 13, 9), seconds: 100),
      ], now);
      expect(stats.perSongSeconds['song-a'], 500);
      expect(stats.perSongSeconds[''], 100);
    });

    test('late-night session counts on its own date (midnight boundary)', () {
      final stats = computePracticeStats([
        _s(DateTime(2026, 7, 14, 23, 59), seconds: 60),
        _s(DateTime(2026, 7, 15, 0, 1), seconds: 60),
      ], now);
      expect(stats.dailySeconds[5], 60);
      expect(stats.dailySeconds[6], 60);
      expect(stats.streakDays, 2);
    });
  });
}
