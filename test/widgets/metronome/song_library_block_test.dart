import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/widgets/metronome/song_library_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestMetronomeNotifier extends MetronomeNotifier {
  TestMetronomeNotifier(this.initialState);

  final MetronomeState initialState;

  @override
  MetronomeState build() => initialState;
}

void main() {
  final createdAt = DateTime(2024);
  final songs = [
    Song(
      id: 'song-1',
      title: 'First Song',
      artist: 'Artist One',
      ourBPM: 100,
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
    Song(
      id: 'song-2',
      title: 'Second Song',
      artist: 'Artist Two',
      ourBPM: 140,
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  ];

  Widget buildWidget({MetronomeState? state}) {
    return ProviderScope(
      overrides: [
        songsProvider.overrideWith((ref) => Stream.value(songs)),
        setlistsProvider.overrideWith((ref) => Stream.value(const [])),
        bandsProvider.overrideWith((ref) => Stream.value(const [])),
        if (state != null)
          metronomeProvider.overrideWith(() => TestMetronomeNotifier(state)),
      ],
      child: const MaterialApp(home: Scaffold(body: SongLibraryBlock())),
    );
  }

  testWidgets('uses an explicit Songs & Setlists launcher', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Songs & Setlists'), findsOneWidget);
    expect(find.byIcon(Icons.library_music_outlined), findsOneWidget);
  });

  testWidgets('shows both tabs and the source selector', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Songs & Setlists'));
    await tester.pumpAndSettle();

    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Setlists'), findsOneWidget);
    expect(find.text('Library source'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets('switches to the setlists tab directly', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Songs & Setlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setlists'));
    await tester.pumpAndSettle();

    expect(find.text('No setlists yet'), findsOneWidget);
  });

  testWidgets('loads a standalone song and closes the sheet', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Songs & Setlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First Song'));
    await tester.pumpAndSettle();

    expect(find.text('First Song'), findsOneWidget);
    expect(find.textContaining('Artist One'), findsOneWidget);
    expect(find.byTooltip('Clear loaded song'), findsOneWidget);
  });

  testWidgets('shows current setlist song and position', (tester) async {
    final setlist = Setlist(
      id: 'setlist-1',
      bandId: '',
      name: 'Show Set',
      songIds: const ['song-1', 'song-2'],
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final state = MetronomeState.initial().copyWith(
      loadedSetlist: setlist,
      loadedSetlistSongs: songs,
      currentSetlistIndex: 1,
      bpm: 140,
    );

    await tester.pumpWidget(buildWidget(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Second Song'), findsOneWidget);
    expect(find.textContaining('Show Set • 2 / 2'), findsOneWidget);
  });

  testWidgets('clear removes the loaded status card', (tester) async {
    final state = MetronomeState.initial().copyWith(loadedSong: songs.first);
    await tester.pumpWidget(buildWidget(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear loaded song'));
    await tester.pump();
    expect(find.text('First Song'), findsNothing);
  });
}
