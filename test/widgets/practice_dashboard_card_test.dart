import 'package:flowgroove/providers/practice_stats_provider.dart';
import 'package:flowgroove/widgets/practice_dashboard_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, PracticeStats stats) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceStatsProvider.overrideWith((ref) async => stats),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PracticeDashboardCard()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('PracticeDashboardCard (#133)', () {
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
