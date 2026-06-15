import 'package:flowgroove/models/beat_mode.dart';
import 'package:flowgroove/screens/songs/components/metronome_pattern_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MetronomePatternEditor Widget', () {
    group('Basic rendering', () {
      testWidgets('renders with default settings', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: MetronomePatternEditor(
                  accentBeats: 4,
                  regularBeats: 1,
                  beatModes: const [],
                  onBeatModeChanged: (_, _, _) {},
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

      testWidgets('renders accentBeats selector', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: MetronomePatternEditor(
                  accentBeats: 4,
                  regularBeats: 1,
                  beatModes: const [],
                  onBeatModeChanged: (_, _, _) {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('Beats per Measure'), findsOneWidget);
        expect(find.text('4'), findsWidgets);
      });

      testWidgets('renders regularBeats selector', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 2,
                beatModes: const [],
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        expect(find.text('Subdivisions per Beat'), findsOneWidget);
        expect(find.text('2'), findsWidgets);
      });

      testWidgets('renders legend', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: const [],
                onBeatModeChanged: (_, _, _) {},
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
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: const [],
                onBeatModeChanged: (_, _, _) {},
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
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 6,
                regularBeats: 2,
                beatModes: const [],
                onBeatModeChanged: (_, _, _) {},
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
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 3,
                beatModes: const [],
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        expect(find.text('Beat'), findsWidgets);
      });

      testWidgets('renders beat mode buttons in grid', (
        tester,
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
                onBeatModeChanged: (_, _, _) {},
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
      testWidgets('renders normal mode as circle', (tester) async {
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
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        // Normal mode shows a circle (Container with decoration)
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('renders accent mode with star icon', (
        tester,
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
                onBeatModeChanged: (_, _, _) {},
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
        tester,
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
                onBeatModeChanged: (_, _, _) {},
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
        tester,
      ) async {
        int newAccentBeats = 4;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: const [],
                onAccentBeatsChanged: (value) {
                  newAccentBeats = value;
                },
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('accent-beats-increase')));
        await tester.pump();

        expect(newAccentBeats, 5);
      });

      testWidgets('decrease accentBeats button works', (
        tester,
      ) async {
        int newAccentBeats = 4;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: const [],
                onAccentBeatsChanged: (value) {
                  newAccentBeats = value;
                },
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('accent-beats-decrease')));
        await tester.pump();

        expect(newAccentBeats, 3);
      });

      testWidgets('decrease button disabled at minimum', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: const [],
                onAccentBeatsChanged: (_) {},
                onBeatModeChanged: (_, _, _) {},
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
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 16,
                regularBeats: 1,
                beatModes: const [],
                onAccentBeatsChanged: (_) {},
                onBeatModeChanged: (_, _, _) {},
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
        tester,
      ) async {
        int newRegularBeats = 1;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: const [],
                onRegularBeatsChanged: (value) {
                  newRegularBeats = value;
                },
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('regular-beats-increase')));
        await tester.pump();

        expect(newRegularBeats, 2);
      });

      testWidgets('decrease regularBeats button works', (
        tester,
      ) async {
        int newRegularBeats = 2;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 2,
                beatModes: const [],
                onRegularBeatsChanged: (value) {
                  newRegularBeats = value;
                },
                onBeatModeChanged: (_, _, _) {},
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
        tester,
      ) async {
        BeatMode? lastMode;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: const [
                  [BeatMode.normal],
                ],
                onBeatModeChanged: (_, _, mode) {
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
        tester,
      ) async {
        BeatMode? lastMode;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: const [
                  [BeatMode.accent],
                ],
                onBeatModeChanged: (_, _, mode) {
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
        tester,
      ) async {
        BeatMode? lastMode;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: const [
                  [BeatMode.silent],
                ],
                onBeatModeChanged: (_, _, mode) {
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
        tester,
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
        tester,
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
                    beatModes: const [],
                    onAccentBeatsChanged: (value) {
                      setState(() => currentAccentBeats = value);
                    },
                    onBeatModeChanged: (_, _, _) {},
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
        tester,
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
                    beatModes: const [],
                    onRegularBeatsChanged: (value) {
                      setState(() => currentRegularBeats = value);
                    },
                    onBeatModeChanged: (_, _, _) {},
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
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 1,
                regularBeats: 1,
                beatModes: const [
                  [BeatMode.accent],
                ],
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        expect(find.text('1'), findsWidgets);
      });

      testWidgets('handles maximum accentBeats (16)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 16,
                regularBeats: 1,
                beatModes: const [],
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        expect(find.text('16'), findsWidgets);
      });

      testWidgets('handles maximum regularBeats (8)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 8,
                beatModes: const [],
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        expect(find.text('8'), findsWidgets);
      });

      testWidgets('handles empty beatModes', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetronomePatternEditor(
                accentBeats: 4,
                regularBeats: 1,
                beatModes: const [],
                onBeatModeChanged: (_, _, _) {},
              ),
            ),
          ),
        );

        // Should still render the grid
        expect(find.text('Beat Pattern'), findsOneWidget);
      });

      testWidgets('handles beatModes smaller than grid', (
        tester,
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
                onBeatModeChanged: (_, _, _) {},
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
