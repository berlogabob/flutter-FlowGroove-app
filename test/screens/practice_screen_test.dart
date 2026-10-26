import 'dart:async';

import 'package:flowgroove/models/metronome_session.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/homework_provider.dart';
import 'package:flowgroove/providers/practice_stats_provider.dart';
import 'package:flowgroove/screens/practice_screen.dart';
import 'package:flowgroove/services/connectivity_service.dart';
import 'package:flowgroove/services/last_practice_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/routed_test_harness.dart';

void main() {
  testWidgets('song lookup failure and confirmed missing song stay distinct', (
    tester,
  ) async {
    final events = StreamController<List<Song>>();
    final now = DateTime(2026, 10, 25);
    try {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/practice-test',
        overrides: [
          lastPracticeContextProvider.overrideWith(
            (ref) async => LastPracticeContext(
              songId: 'resume',
              title: 'Resume practice song',
              bpm: 112,
              updatedAt: DateTime(2026),
            ),
          ),
          offlineProvider.overrideWithValue(false),
          practiceStatsProvider.overrideWith(
            (ref) async => const PracticeStats(
              totalSecondsThisWeek: 120,
              sessionCountThisWeek: 1,
              streakDays: 1,
              dailySeconds: [0, 0, 0, 0, 0, 0, 120],
              perSongSeconds: {'missing': 120},
            ),
          ),
          practiceSessionsProvider.overrideWith(
            (ref) async => [
              MetronomeSession(
                id: 'session',
                startedAt: now,
                startBpm: 100,
                elapsedSeconds: 120,
                songId: 'missing',
              ),
            ],
          ),
          myHomeworkProvider.overrideWith((ref) async => []),
          songsProvider.overrideWith((ref) => events.stream),
        ],
        routes: [
          GoRoute(
            path: '/practice-test',
            builder: (_, _) => const PracticeScreen(),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Resume practice song · 112 BPM'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Loading song…'), findsNWidgets(2));
      expect(find.text('Removed song'), findsNothing);
      events.addError(StateError('private title failure'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Song unavailable'), findsNWidgets(2));
      expect(find.text('Loading song…'), findsNothing);
      expect(find.text('Removed song'), findsNothing);
      expect(find.textContaining('private title failure'), findsNothing);
      events.add([]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Removed song'), findsNWidgets(2));
      expect(find.text('Song unavailable'), findsNothing);
    } finally {
      await events.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('recent sessions loading and error have local retry', (
    tester,
  ) async {
    final pending = Completer<List<MetronomeSession>>();
    Future<List<MetronomeSession>> Function() loadSessions = () =>
        pending.future;
    try {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/practice-test',
        overrides: [
          offlineProvider.overrideWithValue(false),
          practiceStatsProvider.overrideWith(
            (ref) async => PracticeStats.empty,
          ),
          practiceSessionsProvider.overrideWith((ref) => loadSessions()),
          myHomeworkProvider.overrideWith((ref) async => []),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
        routes: [
          GoRoute(
            path: '/practice-test',
            builder: (_, _) => const PracticeScreen(),
          ),
          GoRoute(
            name: 'metronome',
            path: '/metronome',
            builder: (_, _) =>
                const Scaffold(body: Text('Metronome destination')),
          ),
        ],
      );
      await tester.pump();
      expect(find.text('Loading sessions…'), findsOneWidget);
      expect(find.textContaining('No sessions yet'), findsNothing);
      expect(find.text('Metronome'), findsOneWidget);
      await tester.tap(find.text('Metronome'));
      await tester.pumpAndSettle();
      expect(find.text('Metronome destination'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      pending.completeError(StateError('private session diagnostic'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Unable to load sessions'), findsOneWidget);
      expect(find.textContaining('No sessions yet'), findsNothing);
      expect(find.textContaining('private session diagnostic'), findsNothing);
      loadSessions = () async => [];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No sessions yet'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets(
    'song titles resolve after loading and cached titles survive refresh',
    (tester) async {
      final songEvents = StreamController<List<Song>>();
      final now = DateTime.now();
      const stats = PracticeStats(
        totalSecondsThisWeek: 120,
        sessionCountThisWeek: 1,
        streakDays: 1,
        dailySeconds: [0, 0, 0, 0, 0, 0, 120],
        perSongSeconds: {'song-1': 120},
      );
      try {
        await pumpRoutedTestApp(
          tester,
          initialLocation: '/practice-test',
          overrides: [
            offlineProvider.overrideWithValue(false),
            practiceStatsProvider.overrideWith((ref) async => stats),
            practiceSessionsProvider.overrideWith(
              (ref) async => [
                MetronomeSession(
                  id: 's1',
                  startedAt: now,
                  startBpm: 100,
                  elapsedSeconds: 120,
                  songId: 'song-1',
                ),
                MetronomeSession(
                  id: 's2',
                  startedAt: now,
                  startBpm: 100,
                  elapsedSeconds: 60,
                ),
              ],
            ),
            myHomeworkProvider.overrideWith((ref) async => []),
            songsProvider.overrideWith((ref) => songEvents.stream),
          ],
          routes: [
            GoRoute(
              path: '/practice-test',
              builder: (_, _) => const PracticeScreen(),
            ),
          ],
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Removed song'), findsNothing);
        songEvents.add([
          Song(
            id: 'song-1',
            title: 'Actual song title',
            artist: '',
            createdAt: now,
            updatedAt: now,
          ),
        ]);
        await tester.pump();
        await tester.pump();
        expect(find.text('Actual song title'), findsNWidgets(2));
        songEvents.addError(StateError('private song refresh diagnostic'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Actual song title'), findsNWidgets(2));
        expect(find.text('Removed song'), findsNothing);
        expect(find.textContaining('private song diagnostic'), findsNothing);
        expect(find.text('Freestyle'), findsOneWidget);
      } finally {
        await songEvents.close();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets('homework loading and failure keep Quick start usable', (
    tester,
  ) async {
    final pending = Completer<List<HomeworkItem>>();
    Future<List<HomeworkItem>> Function() loadHomework = () => pending.future;
    try {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/practice-test',
        overrides: [
          offlineProvider.overrideWithValue(false),
          practiceStatsProvider.overrideWith(
            (ref) async => PracticeStats.empty,
          ),
          practiceSessionsProvider.overrideWith((ref) async => []),
          myHomeworkProvider.overrideWith((ref) => loadHomework()),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
        routes: [
          GoRoute(
            path: '/practice-test',
            builder: (_, _) => const PracticeScreen(),
          ),
          GoRoute(
            path: '/metronome',
            name: 'metronome',
            builder: (_, _) =>
                const Scaffold(body: Text('Metronome destination')),
          ),
        ],
      );
      await tester.pump();
      expect(find.text('Loading homework…'), findsOneWidget);
      expect(find.textContaining('Nothing open.'), findsNothing);
      await tester.tap(find.text('Metronome'));
      await tester.pumpAndSettle();
      expect(find.text('Metronome destination'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      pending.completeError(StateError('private homework diagnostic'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Unable to load homework'), findsOneWidget);
      expect(find.textContaining('Nothing open.'), findsNothing);
      expect(find.textContaining('private homework diagnostic'), findsNothing);
      expect(find.text('Metronome'), findsOneWidget);
      loadHomework = () async => [];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing open.'), findsOneWidget);
      expect(find.text('Unable to load homework'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
