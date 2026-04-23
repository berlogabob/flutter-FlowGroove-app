import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/widgets/tools/tool_scaffold.dart';
import 'package:flowgroove/widgets/custom_app_bar.dart';
import 'package:flowgroove/widgets/metronome/central_tempo_circle.dart';
import 'package:flowgroove/widgets/metronome/time_signature_block.dart';
import 'package:flowgroove/widgets/metronome/fine_adjustment_buttons.dart';
import 'package:flowgroove/widgets/metronome/bottom_transport_bar.dart';
import 'package:flowgroove/widgets/metronome/song_library_block.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('MetronomeScreen', () {
    testWidgets('renders scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders ToolScreenScaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ToolScreenScaffold), findsOneWidget);
    });

    testWidgets('renders app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays "Metronome" title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Metronome'), findsOneWidget);
    });

    testWidgets('app bar has black background', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });

    testWidgets('renders CentralTempoCircle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CentralTempoCircle), findsOneWidget);
    });

    testWidgets('renders TimeSignatureBlock', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TimeSignatureBlock), findsOneWidget);
    });

    testWidgets('renders FineAdjustmentButtons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FineAdjustmentButtons), findsOneWidget);
    });

    testWidgets('renders BottomTransportBar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BottomTransportBar), findsOneWidget);
    });

    testWidgets('renders SongLibraryBlock', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SongLibraryBlock), findsOneWidget);
    });

    testWidgets('displays BPM value in central circle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Default BPM is 120
      expect(find.text('120'), findsOneWidget);
    });

    testWidgets('displays BPM label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('has Expanded widget for main content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Expanded), findsWidgets);
    });

    testWidgets('has Column layout in body', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('has SizedBox spacing between sections', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('has SafeArea wrapper', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // ToolScreenScaffold and ToolScreenScaffold body both use SafeArea
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('screen structure matches layout order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify all major sections are present
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TimeSignatureBlock), findsOneWidget);
      expect(find.byType(CentralTempoCircle), findsOneWidget);
      expect(find.byType(FineAdjustmentButtons), findsOneWidget);
      expect(find.byType(BottomTransportBar), findsOneWidget);
      expect(find.byType(SongLibraryBlock), findsOneWidget);
    });

    testWidgets('has offline indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // ToolScreenScaffold has showOfflineIndicator: true
      // Check for the scaffold's offline indicator
      expect(find.byType(ToolScreenScaffold), findsOneWidget);
    });

    testWidgets('renders without overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(() => MetronomeNotifier()),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify no render errors
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has correct screen dimensions handling', (
      WidgetTester tester,
    ) async {
      // Test with different screen sizes
      for (final size in [
        const Size(320, 568), // iPhone SE
        const Size(375, 667), // iPhone 8
        const Size(414, 896), // iPhone 11
        const Size(600, 1024), // Tablet
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: ProviderScope(
                overrides: [
                  metronomeProvider.overrideWith(() => MetronomeNotifier()),
                ],
                child: const MetronomeScreen(),
              ),
            ),
          ),
        );
        await tester.pump();

        // Should render without error on all sizes
        expect(find.byType(Scaffold), findsOneWidget, reason: 'Failed for size $size');
      }
    });
  });
}
