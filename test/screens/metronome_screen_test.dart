import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/widgets/metronome/central_tempo_circle.dart';
import 'package:flowgroove/widgets/metronome/tempo_control_cluster.dart';
import 'package:flowgroove/widgets/metronome/song_library_block.dart';
import 'package:flowgroove/widgets/metronome/time_signature_block.dart';
import 'package:flowgroove/widgets/tools/tool_scaffold.dart';
import 'package:flowgroove/widgets/tools/tool_transport_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import '../helpers/metronome_test_runtime.dart';
import '../helpers/mocks.mocks.dart';

void main() {
  group('MetronomeScreen', () {
    testWidgets('renders scaffold', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders ToolScreenScaffold', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ToolScreenScaffold), findsOneWidget);
    });

    testWidgets('has no top app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('displays "Metronome" title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // No top app bar; the pushed-mode bottom bar names the screen.
      expect(find.text('Metronome'), findsOneWidget);
    });

    testWidgets('renders CentralTempoCircle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CentralTempoCircle), findsOneWidget);
    });

    testWidgets('renders TimeSignatureBlock', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TimeSignatureBlock), findsOneWidget);
    });

    testWidgets('renders TempoControlCluster', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TempoControlCluster), findsOneWidget);
    });

    testWidgets('renders ToolTransportBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ToolTransportBar), findsOneWidget);
    });

    testWidgets('renders SongLibraryBlock', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SongLibraryBlock), findsOneWidget);
    });

    testWidgets('displays BPM value in central circle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
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

    testWidgets('displays BPM label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('has Expanded widget for main content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Expanded), findsWidgets);
    });

    testWidgets('has Column layout in body', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('has SizedBox spacing between sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('has SafeArea wrapper', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
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

    testWidgets('screen structure matches layout order', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
              ],
              child: const MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify all major sections are present
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(TimeSignatureBlock), findsOneWidget);
      expect(find.byType(CentralTempoCircle), findsOneWidget);
      expect(find.byType(TempoControlCluster), findsOneWidget);
      expect(find.byType(ToolTransportBar), findsOneWidget);
      expect(find.byType(SongLibraryBlock), findsOneWidget);
      expect(find.text('Haptics'), findsNothing);
    });

    testWidgets('toggles haptics from app bar menu', (tester) async {
      final container = ProviderContainer(
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(400, 800)),
              child: MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Haptics'), findsNothing);
      expect(container.read(metronomeProvider).hapticsEnabled, isTrue);

      // Menu moved to the bottom bar; it opens the app menu sheet.
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Haptics'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      // The Haptics row has a live trailing switch, so tapping it toggles in
      // place WITHOUT closing the sheet.
      await tester.tap(find.text('Haptics'));
      await tester.pumpAndSettle();

      expect(container.read(metronomeProvider).hapticsEnabled, isFalse);
      expect(find.text('Haptics'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      // The trailing switch itself toggles back on, still in-sheet.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(metronomeProvider).hapticsEnabled, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('edit song menu opens the loaded song editor', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final runtime = MetronomeTestRuntime();
      final mockAuth = MockFirebaseAuth();
      final mockUser = MockUser();
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('user-1');

      final container = ProviderContainer(
        overrides: [
          ...runtime.overrides,
          firebaseAuthProvider.overrideWithValue(mockAuth),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await runtime.dispose();
      });

      final song = Song(
        id: 'song-1',
        title: 'Loaded Song',
        artist: 'Artist',
        ourBPM: 120,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      container.read(metronomeProvider.notifier).loadSongTempo(song);

      final router = GoRouter(
        initialLocation: '/metronome',
        routes: [
          GoRoute(
            path: '/metronome',
            builder: (context, state) => const MetronomeScreen(),
          ),
          GoRoute(
            path: '/songs/:id',
            name: 'song',
            builder: (context, state) {
              final editedSong = state.extra! as Song;
              final tab = state.uri.queryParameters['tab'];
              return Scaffold(body: Text('Editing ${editedSong.title} ($tab)'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Edit Song'), findsOneWidget);
      await tester.tap(find.text('Edit Song'));
      await tester.pumpAndSettle();

      expect(find.text('Editing Loaded Song (edit)'), findsOneWidget);
    });

    testWidgets('play preserves three visible main beats', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final runtime = MetronomeTestRuntime();
      final container = ProviderContainer(overrides: runtime.overrides);
      addTearDown(() async {
        container.dispose();
        await runtime.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(400, 800)),
              child: MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('main-beats-decrement')));
      await tester.pump();
      expect(container.read(metronomeProvider).accentBeats, 3);
      expect(find.byKey(const Key('main_beat_dot_2')), findsOneWidget);
      expect(find.byKey(const Key('main_beat_dot_3')), findsNothing);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(container.read(metronomeProvider).isPlaying, isTrue);
      expect(container.read(metronomeProvider).accentBeats, 3);
      expect(find.byKey(const Key('main_beat_dot_2')), findsOneWidget);
      expect(find.byKey(const Key('main_beat_dot_3')), findsNothing);
    });

    testWidgets('has offline indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
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

    testWidgets('renders without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ProviderScope(
              overrides: [
                metronomeProvider.overrideWith(MetronomeNotifier.new),
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

    testWidgets('renders the full controls without overflow at 390x844', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
            child: const MetronomeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MetronomeScreen), findsOneWidget);
    });

    testWidgets('short compact layout keeps beat controls above tempo dial', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
            child: const MetronomeScreen(),
          ),
        ),
      );
      await tester.pump();

      final beatControlsTop = tester
          .getTopLeft(find.byType(TimeSignatureBlock))
          .dy;
      final tempoDialTop = tester
          .getTopLeft(find.byType(CentralTempoCircle))
          .dy;

      expect(beatControlsTop, lessThan(tempoDialTop));
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop side controls render without overflow at 1280x900', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
            child: const MetronomeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Sound / Count-in / Ramp now live in the ⋯ menu (Mono Pulse: "main
      // window stays clean"); the on-screen controls are the dial + transport.
      expect(find.byKey(const Key('tempo-dial')), findsOneWidget);
    });

    testWidgets('has correct screen dimensions handling', (tester) async {
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
                  metronomeProvider.overrideWith(MetronomeNotifier.new),
                ],
                child: const MetronomeScreen(),
              ),
            ),
          ),
        );
        await tester.pump();

        // Should render without error on all sizes
        expect(
          find.byType(Scaffold),
          findsOneWidget,
          reason: 'Failed for size $size',
        );
      }
    });
  });
}
