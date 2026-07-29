import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/screens/performance_sheet_screen.dart';
import 'package:flowgroove/screens/songs/song_editor_screen.dart';
import 'package:flowgroove/screens/songs/components/import_lyrics_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for #96 ("freezing on performance sheet"). Two dispose-time
/// bugs fired every time the sheet was closed, on any song:
///  1. the autoscroll [Ticker] was created lazily, so if autoscroll was never
///     started it was first built inside dispose(), doing a TickerMode ancestor
///     lookup on a deactivated element (debug assert);
///  2. dispose() called `ref.read(wakelockProvider)`, and Riverpod throws a
///     StateError for `ref` use after unmount — in release too.
/// testWidgets fails on any uncaught exception, so opening then disposing the
/// screen (without ever touching autoscroll — the common case) reproduces both.
void main() {
  testWidgets('opens and disposes without throwing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: PerformanceSheetScreen(
              title: 'Song',
              sections: [
                Section(
                  id: 's0',
                  name: 'Verse',
                  chordChart: '[Am]Twinkle [F]twinkle [C]little [G]star',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PerformanceSheetScreen), findsOneWidget);

    // Navigate away -> dispose(). This is where both #96 bugs threw.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(find.byType(PerformanceSheetScreen), findsNothing);
  });

  testWidgets('empty state shows action buttons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: PerformanceSheetScreen(
              title: 'Empty Song',
              sections: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify empty state message is shown
    expect(
      find.text(
        'No lyrics or chords yet.\nAdd them to a section to see the performance sheet.',
      ),
      findsOneWidget,
    );

    // Verify buttons are present
    expect(find.text('Open song editor'), findsOneWidget);
    expect(find.text('Import lyrics & chords'), findsOneWidget);

    // Verify buttons are of correct types
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('open song editor button navigates to song editor', (tester) async {
    final testSong = Song(
      id: 'test-song-id',
      title: 'Test Song',
      artist: 'Test Artist',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: PerformanceSheetScreen(
              title: 'Empty Song',
              sections: [],
              song: testSong,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the open song editor button
    await tester.tap(find.text('Open song editor'));
    await tester.pumpAndSettle();

    // Verify navigation to SongEditorScreen
    expect(find.byType(SongEditorScreen), findsOneWidget);
  });

  testWidgets('import lyrics button opens import dialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: PerformanceSheetScreen(
              title: 'Empty Song',
              sections: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the import lyrics button
    await tester.tap(find.text('Import lyrics & chords'));
    await tester.pumpAndSettle();

    // Verify import dialog is shown
    expect(find.byType(ImportLyricsDialog), findsOneWidget);
  });
}
