import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/metronome/time_signature_controls_widget.dart';
import 'package:flutter_repsync_app/providers/data/metronome_provider.dart';
import 'package:flutter_repsync_app/models/time_signature.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('TimeSignatureControlsWidget', () {
    testWidgets('renders title', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('Time Signature'), findsOneWidget);
    });

    testWidgets('renders help tooltip', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('renders Card widget', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders 6 preset time signature chips', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Count ChoiceChip widgets
      expect(find.byType(ChoiceChip), findsNWidgets(6));
    });

    testWidgets('renders 4/4 preset', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('4/4'), findsWidgets);
    });

    testWidgets('renders 3/4 preset', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('3/4'), findsWidgets);
    });

    testWidgets('renders 6/8 preset', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('6/8'), findsWidgets);
    });

    testWidgets('renders 2/4 preset', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('2/4'), findsWidgets);
    });

    testWidgets('renders 5/4 preset', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('5/4'), findsWidgets);
    });

    testWidgets('renders 7/8 preset', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('7/8'), findsWidgets);
    });

    testWidgets('displays current selection', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('Current: '), findsOneWidget);
      expect(find.text('4/4'), findsWidgets);
    });

    testWidgets('displays helper text', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('Select a common time signature'), findsOneWidget);
    });

    testWidgets('renders divider', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('presets list contains correct time signatures', (
      WidgetTester tester,
    ) async {
      final presets = TimeSignatureControlsWidget.presets;

      expect(presets.length, equals(6));
      expect(
        presets[0],
        equals(const TimeSignature(numerator: 4, denominator: 4)),
      );
      expect(
        presets[1],
        equals(const TimeSignature(numerator: 3, denominator: 4)),
      );
      expect(
        presets[2],
        equals(const TimeSignature(numerator: 6, denominator: 8)),
      );
      expect(
        presets[3],
        equals(const TimeSignature(numerator: 2, denominator: 4)),
      );
      expect(
        presets[4],
        equals(const TimeSignature(numerator: 5, denominator: 4)),
      );
      expect(
        presets[5],
        equals(const TimeSignature(numerator: 7, denominator: 8)),
      );
    });
  });
}
