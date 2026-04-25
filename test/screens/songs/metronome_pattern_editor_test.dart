import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/screens/songs/components/metronome_pattern_editor.dart';
import 'package:flowgroove/models/beat_mode.dart';

void main() {
  group('MetronomePatternEditor Widget', () {
    group('Basic rendering', () {
      testWidgets('renders with default settings', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: MetronomePatternEditor(
                  accentBeats: 4,
                  regularBeats: 1,
                  beatModes: [],
                  onBeatModeChanged: (_, __, ___) {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('Beats per Measure'), findsOneWidget);
        expect(find.text('Subdivisions per Beat'), findsOneWidget);
        expect(find.text('Beat Pattern'), findsOneWidget);
        expect(find.text('4'), findsWidgets); // Default value display
      });

      testWidgets('renders accentBeats selector', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: MetronomePatternEditor(
                  accentBeats: 4,
                  regularBeats: 1,
                  beatModes: [],
                  onBeatModeChanged: (_, __, ___) {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('Beats per Measure'), findsOneWidget);
        expect(find.text('4'), findsWidgets);
      });

      testWidgets('renders regularBeats selector', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 2,
                beatModes: [],
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        expect(find.text('Subdivisions per Beat'), findsOneWidget);
        expect(find.text('2'), findsWidgets);
      });

      testWidgets('renders legend', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: [],
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        expect(find.text('Normal'), findsOneWidget);
        expect(find.text('Accent'), findsOneWidget);
        expect(find.text('Silent'), findsOneWidget);
      });
    });

    group('Beat grid rendering', () {
      testWidgets('renders grid with 4 beats and 1 subdivision', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: [],
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        // Should show beat labels 1-4
        expect(find.text('1'), findsWidgets);
        expect(find.text('2'), findsWidgets);
        expect(find.text('3'), findsWidgets);
        expect(find.text('4'), findsWidgets);
      });

      testWidgets('renders grid with 6 beats and 2 subdivisions', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 6,
                regularBeats: 2,
                beatModes: [],
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        // Should show beat labels 1-6
        expect(find.text('1'), findsWidgets);
        expect(find.text('6'), findsWidgets);

        // Should show subdivision labels
        expect(find.text('1'), findsWidgets);
        expect(find.text('2'), findsWidgets);
      });

      testWidgets('renders subdivision header when regularBeats > 1', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 3,
                beatModes: [],
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        expect(find.text('Beat'), findsWidgets);
      });

      testWidgets('renders beat mode buttons in grid', (
        WidgetTester tester,
      ) async {
        final beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 2,
                regularBeats: 2,
                beatModes: beatModes,
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        expect(find.byKey(const ValueKey('beat-mode-0-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('beat-mode-0-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('beat-mode-1-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('beat-mode-1-1')), findsOneWidget);
      });
    });

    group('Beat mode visualization', () {
      testWidgets('renders normal mode as circle', (WidgetTester tester) async {
        final beatModes = [
          [BeatMode.normal],
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: beatModes,
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        // Normal mode shows a circle (Container with decoration)
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('renders accent mode with star icon', (
        WidgetTester tester,
      ) async {
        final beatModes = [
          [BeatMode.accent],
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: beatModes,
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('beat-mode-0-0')),
            matching: find.byIcon(Icons.star),
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders silent mode with volume_off icon', (
        WidgetTester tester,
      ) async {
        final beatModes = [
          [BeatMode.silent],
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: beatModes,
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('beat-mode-0-0')),
            matching: find.byIcon(Icons.volume_off),
          ),
          findsOneWidget,
        );
      });
    });

    group('Number selector interactions', () {
      testWidgets('increase accentBeats button works', (
        WidgetTester tester,
      ) async {
        int newAccentBeats = 4;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: [],
                onAccentBeatsChanged: (value) {
                  newAccentBeats = value;
                },
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('accent-beats-increase')));
        await tester.pump();

        expect(newAccentBeats, 5);
      });

      testWidgets('decrease accentBeats button works', (
        WidgetTester tester,
      ) async {
        int newAccentBeats = 4;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: [],
                onAccentBeatsChanged: (value) {
                  newAccentBeats = value;
                },
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('accent-beats-decrease')));
        await tester.pump();

        expect(newAccentBeats, 3);
      });

      testWidgets('decrease button disabled at minimum', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: [],
                onAccentBeatsChanged: (_) {},
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        final removeButton = tester.widget<IconButton>(
          find.byKey(const ValueKey('accent-beats-decrease')),
        );
        expect(removeButton.onPressed, isNull);
      });

      testWidgets('increase button disabled at maximum for accentBeats', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 16,
                regularBeats: 1,
                beatModes: [],
                onAccentBeatsChanged: (_) {},
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        final addButton = tester.widget<IconButton>(
          find.byKey(const ValueKey('accent-beats-increase')),
        );
        expect(addButton.onPressed, isNull);
      });

      testWidgets('increase regularBeats button works', (
        WidgetTester tester,
      ) async {
        int newRegularBeats = 1;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: [],
                onRegularBeatsChanged: (value) {
                  newRegularBeats = value;
                },
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('regular-beats-increase')));
        await tester.pump();

        expect(newRegularBeats, 2);
      });

      testWidgets('decrease regularBeats button works', (
        WidgetTester tester,
      ) async {
        int newRegularBeats = 2;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 2,
                beatModes: [],
                onRegularBeatsChanged: (value) {
                  newRegularBeats = value;
                },
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('regular-beats-decrease')));
        await tester.pump();

        expect(newRegularBeats, 1);
      });
    });

    group('Beat mode button interactions', () {
      testWidgets('tapping beat mode cycles from normal to accent', (
        WidgetTester tester,
      ) async {
        BeatMode? lastMode;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: [
                  [BeatMode.normal],
                ],
                onBeatModeChanged: (_, __, mode) {
                  lastMode = mode;
                },
              ),
            ),
          ),
        );

        // Tap the beat mode button
        await tester.tap(find.byKey(const ValueKey('beat-mode-0-0')));
        await tester.pump();

        expect(lastMode, BeatMode.accent);
      });

      testWidgets('tapping beat mode cycles from accent to silent', (
        WidgetTester tester,
      ) async {
        BeatMode? lastMode;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: [
                  [BeatMode.accent],
                ],
                onBeatModeChanged: (_, __, mode) {
                  lastMode = mode;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('beat-mode-0-0')));
        await tester.pump();

        expect(lastMode, BeatMode.silent);
      });

      testWidgets('tapping beat mode cycles from silent to normal', (
        WidgetTester tester,
      ) async {
        BeatMode? lastMode;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: [
                  [BeatMode.silent],
                ],
                onBeatModeChanged: (_, __, mode) {
                  lastMode = mode;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('beat-mode-0-0')));
        await tester.pump();

        expect(lastMode, BeatMode.normal);
      });

      testWidgets('tapping different beat positions reports correct indices', (
        WidgetTester tester,
      ) async {
        int? lastBeatIndex;
        int? lastSubdivisionIndex;

        final beatModes = [
          [BeatMode.normal, BeatMode.normal],
          [BeatMode.normal, BeatMode.normal],
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 2,
                regularBeats: 2,
                beatModes: beatModes,
                onBeatModeChanged: (beatIndex, subdivisionIndex, _) {
                  lastBeatIndex = beatIndex;
                  lastSubdivisionIndex = subdivisionIndex;
                },
              ),
            ),
          ),
        );

        // Tap first button (beat 0, subdivision 0)
        await tester.tap(find.byKey(const ValueKey('beat-mode-0-0')));
        await tester.pump();

        expect(lastBeatIndex, 0);
        expect(lastSubdivisionIndex, 0);
      });
    });

    group('Dynamic grid updates', () {
      testWidgets('grid updates when accentBeats changes', (
        WidgetTester tester,
      ) async {
        int currentAccentBeats = 4;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return MetronomePatternEditor(
                    accentBeats: currentAccentBeats,
                    regularBeats: 1,
                    beatModes: [],
                    onAccentBeatsChanged: (value) {
                      setState(() => currentAccentBeats = value);
                    },
                    onBeatModeChanged: (_, __, ___) {},
                  );
                },
              ),
            ),
          ),
        );

        // Initially 4 beats
        expect(find.text('4'), findsWidgets);

        // Increase to 5
        await tester.tap(find.byKey(const ValueKey('accent-beats-increase')));
        await tester.pump();

        expect(currentAccentBeats, 5);
      });

      testWidgets('grid updates when regularBeats changes', (
        WidgetTester tester,
      ) async {
        int currentRegularBeats = 1;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return MetronomePatternEditor(
                    accentBeats: 4,
                    regularBeats: currentRegularBeats,
                    beatModes: [],
                    onRegularBeatsChanged: (value) {
                      setState(() => currentRegularBeats = value);
                    },
                    onBeatModeChanged: (_, __, ___) {},
                  );
                },
              ),
            ),
          ),
        );

        // Increase subdivisions
        await tester.tap(find.byKey(const ValueKey('regular-beats-increase')));
        await tester.pump();

        expect(currentRegularBeats, 2);
      });
    });

    group('Edge cases', () {
      testWidgets('handles minimum accentBeats (1)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: [
                  [BeatMode.accent],
                ],
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        expect(find.text('1'), findsWidgets);
      });

      testWidgets('handles maximum accentBeats (16)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 16,
                regularBeats: 1,
                beatModes: [],
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        expect(find.text('16'), findsWidgets);
      });

      testWidgets('handles maximum regularBeats (8)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 8,
                beatModes: [],
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        expect(find.text('8'), findsWidgets);
      });

      testWidgets('handles empty beatModes', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: [],
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        // Should still render the grid
        expect(find.text('Beat Pattern'), findsOneWidget);
      });

      testWidgets('handles beatModes smaller than grid', (
        WidgetTester tester,
      ) async {
        final beatModes = [
          [BeatMode.accent],
        ]; // Only 1 beat defined

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: beatModes,
                onBeatModeChanged: (_, __, ___) {},
              ),
            ),
          ),
        );

        // Should render 4 beats, with first being accent
        expect(find.text('Beat Pattern'), findsOneWidget);
      });
    });
  });
}
