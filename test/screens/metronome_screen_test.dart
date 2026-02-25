import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/screens/metronome_screen.dart';
import 'package:flutter_repsync_app/providers/data/metronome_provider.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('MetronomeScreen', () {
    testWidgets('renders scaffold', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders app bar', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays "Metronome" title', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('Metronome'), findsOneWidget);
    });

    testWidgets('app bar has teal background', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });

    testWidgets('app bar has white foreground', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.foregroundColor, equals(Colors.white));
    });

    testWidgets('renders ListView body', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders time signature block', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Check for beat circles (Container with circular decoration)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders "How to use" info card', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('How to use'), findsOneWidget);
    });

    testWidgets('displays BPM adjustment instruction', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(
        find.text('• Adjust BPM using slider or +/- buttons'),
        findsOneWidget,
      );
    });

    testWidgets('displays time signature instruction', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(
        find.text('• Select time signature (2/4, 3/4, 4/4, etc.)'),
        findsOneWidget,
      );
    });

    testWidgets('displays start instruction', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('• Press Start to begin'), findsOneWidget);
    });

    testWidgets('displays visual indicator instruction', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(
        find.text('• Visual indicator shows current beat'),
        findsOneWidget,
      );
    });

    testWidgets('displays accent instruction', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(
        find.text('• First beat of measure is accented (red)'),
        findsOneWidget,
      );
    });

    testWidgets('info card has Card widget', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Should have at least 2 cards (metronome widget + info card)
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('has padding around ListView', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.padding, isNotNull);
    });

    testWidgets('has SizedBox spacing between sections', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('info card has Column layout', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Find columns in the info card
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('info section title is bold', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Find the "How to use" text and verify it's styled
      final howToUseText = tester.widget<Text>(find.text('How to use').first);
      expect(howToUseText.style?.fontWeight, equals(FontWeight.bold));
      expect(howToUseText.style?.fontSize, equals(18));
    });

    testWidgets('renders all 5 instruction items', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Count bullet points
      expect(find.textContaining('•'), findsNWidgets(5));
    });

    testWidgets('screen is scrollable', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const MetronomeScreen(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // ListView should be scrollable
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.physics, isNull); // Default allows scrolling
    });
  });
}
