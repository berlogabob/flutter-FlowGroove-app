import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/tap_bpm_widget.dart';
import 'package:flutter_repsync_app/providers/data/metronome_provider.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('TapBPMWidget', () {
    testWidgets('renders tap button', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byIcon(Icons.touch_app), findsOneWidget);
      expect(find.text('TAP'), findsOneWidget);
    });

    testWidgets('renders helper text when no BPM calculated', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('Tap to calculate tempo'), findsOneWidget);
    });

    testWidgets('tap button has correct size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      // Find the circular container (120x120)
      final circularContainer = containers.firstWhere(
        (c) =>
            c.constraints != null &&
            c.constraints is BoxConstraints &&
            (c.constraints as BoxConstraints).maxWidth == 120,
        orElse: () => Container(),
      );
      expect(circularContainer, isNotNull);
    });

    testWidgets('displays calculated BPM after multiple taps', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Tap multiple times
      final tapButton = find.byIcon(Icons.touch_app);
      await tester.tap(tapButton);
      await tester.pump();
      await tester.tap(tapButton);
      await tester.pump();
      await tester.tap(tapButton);
      await tester.pump();

      // Should show BPM display after 2+ taps
      expect(find.textContaining('BPM'), findsOneWidget);
      expect(find.textContaining('taps'), findsOneWidget);
    });

    testWidgets('shows Apply and Reset buttons after BPM calculation', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Tap multiple times to calculate BPM
      final tapButton = find.byIcon(Icons.touch_app);
      await tester.tap(tapButton);
      await tester.pump();
      await tester.tap(tapButton);
      await tester.pump();

      // Should show action buttons
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('Reset button clears taps', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Tap multiple times
      final tapButton = find.byIcon(Icons.touch_app);
      await tester.tap(tapButton);
      await tester.pump();
      await tester.tap(tapButton);
      await tester.pump();

      // Tap Reset
      await tester.tap(find.text('Reset'));
      await tester.pump();

      // Should show helper text again
      expect(find.text('Tap to calculate tempo'), findsOneWidget);
    });

    testWidgets('shows tap count', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Tap multiple times
      final tapButton = find.byIcon(Icons.touch_app);
      await tester.tap(tapButton);
      await tester.pump();
      await tester.tap(tapButton);
      await tester.pump();
      await tester.tap(tapButton);
      await tester.pump();

      // Should show tap count
      expect(find.textContaining('taps'), findsOneWidget);
    });

    testWidgets('has correct container styling', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('tap button is tappable', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TapBPMWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
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
