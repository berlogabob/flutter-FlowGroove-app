import 'dart:async';

import 'package:flowgroove/providers/practice_stats_provider.dart';
import 'package:flowgroove/widgets/practice_dashboard_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/routed_test_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    FutureOr<PracticeStats> stats, {
    bool tappable = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceStatsProvider.overrideWith((ref) async => stats)],
        child: MaterialApp(
          home: Scaffold(body: PracticeDashboardCard(tappable: tappable)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('PracticeDashboardCard (#133)', () {
    testWidgets('readonly empty card does not announce a tap action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pump(tester, PracticeStats.empty, tappable: false);
        final label = tester
            .getSemantics(find.byType(PracticeDashboardCard))
            .getSemanticsData()
            .label;
        expect(label, isNot(contains('Tap to start')));
        expect(label, contains('Start the metronome to log time'));
        expect(find.text('Tap to start'), findsNothing);
        expect(find.text('Start the metronome to log time'), findsOneWidget);
        await pump(tester, PracticeStats.empty);
        expect(
          tester
              .getSemantics(find.byType(PracticeDashboardCard))
              .getSemanticsData()
              .label,
          contains('Tap to start practicing'),
        );
        expect(find.text('Tap to start'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('loading preserves tappable and non-tappable navigation', (
      tester,
    ) async {
      for (final tappable in [false, true]) {
        final pending = Completer<PracticeStats>();
        await pumpRoutedTestApp(
          tester,
          initialLocation: '/card',
          overrides: [
            practiceStatsProvider.overrideWith((ref) => pending.future),
          ],
          routes: [
            GoRoute(
              path: '/card',
              builder: (_, _) =>
                  Scaffold(body: PracticeDashboardCard(tappable: tappable)),
            ),
            GoRoute(
              path: '/practice',
              name: 'practice',
              builder: (_, _) =>
                  const Scaffold(body: Text('Practice destination')),
            ),
          ],
        );
        await tester.tap(find.text('Loading practice…'));
        await tester.pumpAndSettle();
        expect(
          find.text('Practice destination'),
          tappable ? findsOneWidget : findsNothing,
        );
        if (!tappable) {
          expect(find.text('Loading practice…'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('refresh keeps available practice stats visible', (
      tester,
    ) async {
      const stats = PracticeStats(
        totalSecondsThisWeek: 600,
        sessionCountThisWeek: 1,
        streakDays: 1,
        dailySeconds: [0, 0, 0, 0, 0, 0, 600],
        perSongSeconds: {},
      );
      Future<PracticeStats> Function() load = () async => stats;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [practiceStatsProvider.overrideWith((ref) => load())],
          child: const MaterialApp(
            home: Scaffold(body: PracticeDashboardCard()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('10 min'), findsOneWidget);
      final pending = Completer<PracticeStats>();
      load = () => pending.future;
      ProviderScope.containerOf(
        tester.element(find.byType(PracticeDashboardCard)),
      ).invalidate(practiceStatsProvider);
      await tester.pump();
      expect(find.text('10 min'), findsOneWidget);
      expect(find.text('Loading practice…'), findsNothing);
      pending.complete(PracticeStats.empty);
      await tester.pump();
      await tester.pump();
      expect(find.text('No practice yet'), findsOneWidget);
    });

    testWidgets('loading and failure never claim an empty practice week', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final pending = Completer<PracticeStats>();
      try {
        await pump(tester, pending.future);
        final card = find.byType(PracticeDashboardCard);
        expect(find.text('Loading practice…'), findsOneWidget);
        expect(find.text('No practice yet'), findsNothing);
        expect(
          tester.getSemantics(card).getSemanticsData().label,
          contains('Loading practice'),
        );
        pending.completeError(StateError('private diagnostic'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Unable to load practice'), findsOneWidget);
        expect(find.text('No practice yet'), findsNothing);
        expect(find.textContaining('private diagnostic'), findsNothing);
        expect(
          tester.getSemantics(card).getSemanticsData().label,
          contains('Unable to load practice'),
        );
      } finally {
        semantics.dispose();
      }
    });

    test('formatMinutes renders seconds, minutes and hours', () {
      // Sub-minute shows real seconds, not a misleading "0 min" (UX audit F-020).
      expect(PracticeDashboardCard.formatMinutes(59), '59s');
      expect(PracticeDashboardCard.formatMinutes(0), '0s');
      expect(PracticeDashboardCard.formatMinutes(600), '10 min');
      expect(PracticeDashboardCard.formatMinutes(3900), '1h 5m');
    });

    testWidgets('shows week total, sessions and streak', (tester) async {
      await pump(
        tester,
        const PracticeStats(
          totalSecondsThisWeek: 8520, // 2h 22m
          sessionCountThisWeek: 5,
          streakDays: 3,
          dailySeconds: [0, 600, 0, 1200, 2400, 1320, 3000],
          perSongSeconds: {},
        ),
      );

      expect(find.text('2h 22m'), findsOneWidget);
      expect(find.textContaining('5 sessions'), findsOneWidget);
      expect(find.textContaining('3-day streak'), findsOneWidget);
    });

    testWidgets('empty week shows the start nudge', (tester) async {
      await pump(tester, PracticeStats.empty);
      expect(find.text('No practice yet'), findsOneWidget);
      expect(find.text('Tap to start'), findsOneWidget);
    });
  });
}
