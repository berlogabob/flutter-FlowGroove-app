import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/song_bpm_badge.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('SongBPMBadge', () {
    testWidgets('renders nothing when BPM is null', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongBPMBadge(bpm: null),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders BPM badge with valid BPM', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongBPMBadge(bpm: 120),
      );

      expect(find.text('120 BPM'), findsOneWidget);
      expect(find.byIcon(Icons.speed), findsOneWidget);
    });

    testWidgets('renders with label when showLabel is true', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SongBPMBadge(bpm: 100, showLabel: true),
      );

      expect(find.text('100 BPM'), findsOneWidget);
    });

    testWidgets('hides label when showLabel is false', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SongBPMBadge(bpm: 100, showLabel: false),
      );

      expect(find.text('100 BPM'), findsNothing);
      expect(find.byIcon(Icons.speed), findsOneWidget);
    });

    testWidgets('shows play icon when onTap is provided', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        SongBPMBadge(bpm: 120, onTap: () {}),
      );

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('hides play icon when onTap is null', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SongBPMBadge(bpm: 120, onTap: null),
      );

      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    });

    testWidgets('calls onTap when badge is tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      await pumpAppWidget(
        tester,
        SongBPMBadge(
          bpm: 120,
          onTap: () => wasTapped = true,
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('has correct container styling', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongBPMBadge(bpm: 120),
      );

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(container.decoration, isA<BoxDecoration>());
    });

    testWidgets('displays different BPM values correctly', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SongBPMBadge(bpm: 60),
      );
      expect(find.text('60 BPM'), findsOneWidget);

      await pumpAppWidget(
        tester,
        const SongBPMBadge(bpm: 200),
      );
      expect(find.text('200 BPM'), findsOneWidget);
    });
  });
}
