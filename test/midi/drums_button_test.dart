import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/drum_active_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/widgets/metronome/drum_practice_panel.dart';
import 'package:flowgroove/widgets/metronome/song_library_block.dart';
import 'package:flowgroove/widgets/metronome/time_signature_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/metronome_test_runtime.dart';
import '../helpers/mocks.mocks.dart';

void main() {
  late MetronomeTestRuntime runtime;
  late ProviderContainer container;

  setUp(() {
    runtime = MetronomeTestRuntime();
    final auth = MockFirebaseAuth();
    when(auth.currentUser).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        ...runtime.overrides,
        firebaseAuthProvider.overrideWithValue(auth),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await runtime.dispose();
  });

  final drumsButton = find.widgetWithText(OutlinedButton, 'Drums');

  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MetronomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Drums button shown without an active song, disabled', (
    tester,
  ) async {
    await pumpScreen(tester, const Size(360, 800));

    expect(drumsButton, findsOneWidget);
    expect(find.byIcon(Icons.album_outlined), findsOneWidget);
    expect(tester.widget<OutlinedButton>(drumsButton).enabled, isFalse);
    expect(find.text('Pick a song first'), findsOneWidget);
    expect(find.byType(DrumPracticePanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 800), const Size(800, 360)]) {
    testWidgets('Drums button stays below the song library at $size', (
      tester,
    ) async {
      await pumpScreen(tester, size);
      container
          .read(metronomeProvider.notifier)
          .loadSongTempo(
            Song(
              id: 'song-1',
              title: 'Loaded Song',
              artist: 'Artist',
              ourBPM: 120,
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
            ),
          );
      await tester.pumpAndSettle();

      expect(drumsButton, findsOneWidget);
      expect(
        find.descendant(
          of: drumsButton,
          matching: find.byIcon(Icons.album_outlined),
        ),
        findsOneWidget,
      );
      expect(find.byType(DrumPracticePanel), findsNothing);
      await tester.ensureVisible(drumsButton);
      await tester.pumpAndSettle();

      final buttonBounds = tester.getRect(drumsButton);
      final signatureBounds = tester.getRect(find.byType(TimeSignatureBlock));
      final libraryBounds = tester.getRect(find.byType(SongLibraryBlock));
      expect(buttonBounds.overlaps(signatureBounds), isFalse);
      expect(buttonBounds.top, greaterThanOrEqualTo(libraryBounds.bottom));
      expect(drumsButton.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
