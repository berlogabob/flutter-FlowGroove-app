import 'package:flowgroove/widgets/tap_bpm_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/metronome_test_runtime.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('TapBPMWidget', () {
    List<dynamic> metronomeOverrides() {
      return buildMetronomeTestOverrides(overrideMetronomeProvider: true);
    }

    Future<void> tapAtInterval(
      WidgetTester tester,
      Finder tapButton, {
      int count = 2,
      Duration interval = const Duration(milliseconds: 250),
    }) async {
      for (int index = 0; index < count; index++) {
        await tester.tap(tapButton);
        await tester.pump();
        if (index < count - 1) {
          await tester.runAsync(() => Future<void>.delayed(interval));
          await tester.pump();
        }
      }
    }

    testWidgets('renders tap button', (tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: metronomeOverrides(),
      );

      expect(find.byIcon(Icons.touch_app), findsOneWidget);
      expect(find.text('TAP'), findsOneWidget);
    });

    testWidgets('renders helper text when no BPM calculated', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: metronomeOverrides(),
      );

      expect(find.text('Tap to calculate tempo'), findsOneWidget);
    });

    testWidgets('tap button has correct size', (tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: metronomeOverrides(),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCircularContainer = containers.any(
        (container) => container.constraints?.maxWidth == 120,
      );
      expect(hasCircularContainer, isTrue);
    });

    testWidgets('displays calculated BPM after multiple taps', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: metronomeOverrides(),
      );

      final tapButton = find.byIcon(Icons.touch_app);
      await tapAtInterval(tester, tapButton, count: 3);

      expect(find.textContaining('BPM'), findsOneWidget);
      expect(find.text('3 taps'), findsOneWidget);
    });

    testWidgets('shows Apply and Reset buttons after BPM calculation', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: metronomeOverrides(),
      );

      final tapButton = find.byIcon(Icons.touch_app);
      await tapAtInterval(tester, tapButton);

      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('Reset button clears taps', (tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: metronomeOverrides(),
      );

      final tapButton = find.byIcon(Icons.touch_app);
      await tapAtInterval(tester, tapButton);

      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(find.text('Tap to calculate tempo'), findsOneWidget);
    });

    testWidgets('shows tap count', (tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: metronomeOverrides(),
      );

      final tapButton = find.byIcon(Icons.touch_app);
      await tapAtInterval(tester, tapButton, count: 3);

      expect(find.text('3 taps'), findsOneWidget);
    });

    testWidgets('has correct container styling', (tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: metronomeOverrides(),
      );

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('tap button is tappable', (tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: metronomeOverrides(),
      );

      final tapButton = find.byIcon(Icons.touch_app);
      expect(tapButton, findsOneWidget);

      // Should be able to tap
      await tester.tap(tapButton);
      await tester.pump();

      // Widget should still be present
      expect(find.byIcon(Icons.touch_app), findsOneWidget);
    });
  });
}
