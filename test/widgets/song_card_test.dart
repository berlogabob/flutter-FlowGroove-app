import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/widgets/song_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAppWidget(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(MaterialApp(home: Material(child: widget)));
  await tester.pump();
  await tester.pump();
}

Finder findText(String text) => find.text(text);

Finder findIcon(IconData icon) => find.byIcon(icon);

void verifyNotFound(Finder finder) {
  expect(finder, findsNothing);
}

Song createMockSong({
  String id = 'test-song-id',
  String title = 'Test Song',
  String artist = 'Test Artist',
  int? originalBPM,
  int? ourBPM,
  String? originalKey,
  String? ourKey,
  String? spotifyUrl,
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    originalBPM: originalBPM,
    ourBPM: ourBPM,
    originalKey: originalKey,
    ourKey: ourKey,
    spotifyUrl: spotifyUrl,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  group('SongCard', () {
    late Song mockSong;

    setUp(() {
      mockSong = createMockSong(
        id: 'test-song',
        ourBPM: 120,
        ourKey: 'C',
        spotifyUrl: 'https://open.spotify.com/track/test',
      );
    });

    testWidgets('renders song card with title and artist', (
      tester,
    ) async {
      await pumpAppWidget(tester, SongCard(song: mockSong));

      expect(findText('Test Song'), findsOneWidget);
      expect(findText('Test Artist'), findsOneWidget);
    });

    testWidgets('renders music note icon', (tester) async {
      await pumpAppWidget(tester, SongCard(song: mockSong));

      expect(findIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('renders BPM badge when ourBPM is set', (
      tester,
    ) async {
      await pumpAppWidget(tester, SongCard(song: mockSong));

      expect(find.text('120'), findsWidgets);
    });

    testWidgets('renders key when ourKey is set', (tester) async {
      await pumpAppWidget(tester, SongCard(song: mockSong));

      expect(find.text('C'), findsWidgets);
    });

    testWidgets('renders Spotify play button when spotifyUrl is set', (
      tester,
    ) async {
      await pumpAppWidget(tester, SongCard(song: mockSong));

      expect(findIcon(Icons.play_circle_fill), findsOneWidget);
    });

    testWidgets('does not render Spotify button when spotifyUrl is null', (
      tester,
    ) async {
      final songWithoutSpotify = mockSong.copyWith(spotifyUrl: null);

      await pumpAppWidget(tester, SongCard(song: songWithoutSpotify));

      verifyNotFound(findIcon(Icons.play_circle_fill));
    });

    testWidgets(
      'does not render Spotify button when showSpotifyButton is false',
      (tester) async {
        await pumpAppWidget(
          tester,
          SongCard(song: mockSong, showSpotifyButton: false),
        );

        verifyNotFound(findIcon(Icons.play_circle_fill));
      },
    );

    testWidgets('renders edit button', (tester) async {
      await pumpAppWidget(tester, SongCard(song: mockSong));

      expect(findIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('calls onEdit when edit button is tapped', (
      tester,
    ) async {
      bool wasEdited = false;

      await pumpAppWidget(
        tester,
        SongCard(song: mockSong, onEdit: () => wasEdited = true),
      );

      await tester.tap(findIcon(Icons.edit));
      await tester.pump();

      expect(wasEdited, isTrue);
    });

    testWidgets('calls onPlaySpotify when Spotify button is tapped', (
      tester,
    ) async {
      bool wasPlayed = false;

      await pumpAppWidget(
        tester,
        SongCard(song: mockSong, onPlaySpotify: () => wasPlayed = true),
      );

      await tester.tap(findIcon(Icons.play_circle_fill));
      await tester.pump();

      expect(wasPlayed, isTrue);
    });

    testWidgets('renders metronome action when song has tempo data', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        SongCard(song: mockSong, onOpenMetronome: () {}),
      );

      expect(
        find.byKey(const ValueKey('song-card-open-metronome')),
        findsOneWidget,
      );
      expect(find.byTooltip('Open in Metronome'), findsOneWidget);
    });

    testWidgets('does not render metronome action without metronome data', (
      tester,
    ) async {
      final songWithoutTempo = mockSong.copyWith(ourBPM: null);

      await pumpAppWidget(
        tester,
        SongCard(song: songWithoutTempo, onOpenMetronome: () {}),
      );

      expect(
        find.byKey(const ValueKey('song-card-open-metronome')),
        findsNothing,
      );
    });

    testWidgets('calls onOpenMetronome when metronome action is tapped', (
      tester,
    ) async {
      var openedMetronome = false;

      await pumpAppWidget(
        tester,
        SongCard(song: mockSong, onOpenMetronome: () => openedMetronome = true),
      );

      await tester.tap(find.byKey(const ValueKey('song-card-open-metronome')));
      await tester.pump();

      expect(openedMetronome, isTrue);
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      bool wasTapped = false;

      await pumpAppWidget(
        tester,
        SongCard(song: mockSong, onEdit: () => wasTapped = true),
      );

      await tester.tap(find.text('Test Song'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('does not render BPM badge when ourBPM is null', (
      tester,
    ) async {
      final songWithoutBpm = mockSong.copyWith(ourBPM: null);

      await pumpAppWidget(tester, SongCard(song: songWithoutBpm));

      // BPM badge should not be present
      verifyNotFound(find.text('BPM'));
    });

    testWidgets('does not render key when ourKey is null', (
      tester,
    ) async {
      final songWithoutKey = mockSong.copyWith(ourKey: null);

      await pumpAppWidget(tester, SongCard(song: songWithoutKey));

      // Key should not be displayed in trailing
      expect(find.text('C'), findsNothing);
    });

    testWidgets('renders as Card widget', (tester) async {
      await pumpAppWidget(tester, SongCard(song: mockSong));

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders as ListTile', (tester) async {
      await pumpAppWidget(tester, SongCard(song: mockSong));

      expect(find.byType(ListTile), findsOneWidget);
    });
  });

  group('CompactSongCard', () {
    late Song mockSong;

    setUp(() {
      mockSong = createMockSong(
        id: 'test-song',
        title: 'Compact Song',
        artist: 'Compact Artist',
        ourBPM: 100,
        ourKey: 'D',
      );
    });

    testWidgets('renders compact card with title and artist', (
      tester,
    ) async {
      await pumpAppWidget(tester, CompactSongCard(song: mockSong));

      expect(findText('Compact Song'), findsOneWidget);
      expect(findText('Compact Artist'), findsOneWidget);
    });

    testWidgets('renders key when available', (tester) async {
      await pumpAppWidget(tester, CompactSongCard(song: mockSong));

      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('renders BPM when available', (tester) async {
      await pumpAppWidget(tester, CompactSongCard(song: mockSong));

      expect(find.text('100 BPM'), findsOneWidget);
    });

    testWidgets('does not render key when not available', (
      tester,
    ) async {
      final songWithoutKey = mockSong.copyWith(ourKey: null);

      await pumpAppWidget(tester, CompactSongCard(song: songWithoutKey));

      expect(find.text('D'), findsNothing);
    });

    testWidgets('does not render BPM when not available', (
      tester,
    ) async {
      final songWithoutBpm = mockSong.copyWith(ourBPM: null);

      await pumpAppWidget(tester, CompactSongCard(song: songWithoutBpm));

      expect(find.text('BPM'), findsNothing);
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      bool wasTapped = false;

      await pumpAppWidget(
        tester,
        CompactSongCard(song: mockSong, onTap: () => wasTapped = true),
      );

      await tester.tap(find.text('Compact Song'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('renders compact metronome action when song has tempo data', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        CompactSongCard(song: mockSong, onOpenMetronome: () {}),
      );

      expect(
        find.byKey(const ValueKey('compact-song-card-open-metronome')),
        findsOneWidget,
      );
    });

    testWidgets('calls compact onOpenMetronome when action is tapped', (
      tester,
    ) async {
      var openedMetronome = false;

      await pumpAppWidget(
        tester,
        CompactSongCard(
          song: mockSong,
          onOpenMetronome: () => openedMetronome = true,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('compact-song-card-open-metronome')),
      );
      await tester.pump();

      expect(openedMetronome, isTrue);
    });

    testWidgets('renders as Card widget', (tester) async {
      await pumpAppWidget(tester, CompactSongCard(song: mockSong));

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders as ListTile', (tester) async {
      await pumpAppWidget(tester, CompactSongCard(song: mockSong));

      expect(find.byType(ListTile), findsOneWidget);
    });
  });
}
