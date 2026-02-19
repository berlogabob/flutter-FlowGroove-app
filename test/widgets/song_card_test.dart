import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/song_card.dart';
import 'package:flutter_repsync_app/models/song.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mocks.dart';

void main() {
  group('SongCard', () {
    late Song mockSong;

    setUp(() {
      mockSong = MockDataHelper.createMockSong(
        id: 'test-song',
        title: 'Test Song',
        artist: 'Test Artist',
        ourBPM: 120,
        ourKey: 'C',
        spotifyUrl: 'https://open.spotify.com/track/test',
      );
    });

    testWidgets('renders song card with title and artist', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        SongCard(song: mockSong),
      );

      expect(findText('Test Song'), findsOneWidget);
      expect(findText('Test Artist'), findsOneWidget);
    });

    testWidgets('renders music note icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        SongCard(song: mockSong),
      );

      expect(findIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('renders BPM badge when ourBPM is set', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        SongCard(song: mockSong),
      );

      expect(find.text('120'), findsWidgets);
    });

    testWidgets('renders key when ourKey is set', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        SongCard(song: mockSong),
      );

      expect(find.text('C'), findsWidgets);
    });

    testWidgets('renders Spotify play button when spotifyUrl is set', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        SongCard(song: mockSong),
      );

      expect(findIcon(Icons.play_circle_fill), findsOneWidget);
    });

    testWidgets('does not render Spotify button when spotifyUrl is null', (WidgetTester tester) async {
      final songWithoutSpotify = mockSong.copyWith(spotifyUrl: null);

      await pumpAppWidget(
        tester,
        SongCard(song: songWithoutSpotify),
      );

      verifyNotFound(findIcon(Icons.play_circle_fill));
    });

    testWidgets('does not render Spotify button when showSpotifyButton is false', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        SongCard(
          song: mockSong,
          showSpotifyButton: false,
        ),
      );

      verifyNotFound(findIcon(Icons.play_circle_fill));
    });

    testWidgets('renders edit button', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        SongCard(song: mockSong),
      );

      expect(findIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('calls onEdit when edit button is tapped', (WidgetTester tester) async {
      bool wasEdited = false;

      await pumpAppWidget(
        tester,
        SongCard(
          song: mockSong,
          onEdit: () => wasEdited = true,
        ),
      );

      await tester.tap(findIcon(Icons.edit));
      await tester.pump();

      expect(wasEdited, isTrue);
    });

    testWidgets('calls onPlaySpotify when Spotify button is tapped', (WidgetTester tester) async {
      bool wasPlayed = false;

      await pumpAppWidget(
        tester,
        SongCard(
          song: mockSong,
          onPlaySpotify: () => wasPlayed = true,
        ),
      );

      await tester.tap(findIcon(Icons.play_circle_fill));
      await tester.pump();

      expect(wasPlayed, isTrue);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      await pumpAppWidget(
        tester,
        SongCard(
          song: mockSong,
          onEdit: () => wasTapped = true,
        ),
      );

      await tester.tap(find.text('Test Song'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('does not render BPM badge when ourBPM is null', (WidgetTester tester) async {
      final songWithoutBpm = mockSong.copyWith(ourBPM: null);

      await pumpAppWidget(
        tester,
        SongCard(song: songWithoutBpm),
      );

      // BPM badge should not be present
      verifyNotFound(find.text('BPM'));
    });

    testWidgets('does not render key when ourKey is null', (WidgetTester tester) async {
      final songWithoutKey = mockSong.copyWith(ourKey: null);

      await pumpAppWidget(
        tester,
        SongCard(song: songWithoutKey),
      );

      // Key should not be displayed in trailing
      expect(find.text('C'), findsNothing);
    });

    testWidgets('renders as Card widget', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        SongCard(song: mockSong),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders as ListTile', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        SongCard(song: mockSong),
      );

      expect(find.byType(ListTile), findsOneWidget);
    });
  });

  group('CompactSongCard', () {
    late Song mockSong;

    setUp(() {
      mockSong = MockDataHelper.createMockSong(
        id: 'test-song',
        title: 'Compact Song',
        artist: 'Compact Artist',
        ourBPM: 100,
        ourKey: 'D',
      );
    });

    testWidgets('renders compact card with title and artist', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        CompactSongCard(song: mockSong),
      );

      expect(findText('Compact Song'), findsOneWidget);
      expect(findText('Compact Artist'), findsOneWidget);
    });

    testWidgets('renders key when available', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        CompactSongCard(song: mockSong),
      );

      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('renders BPM when available', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        CompactSongCard(song: mockSong),
      );

      expect(find.text('100 BPM'), findsOneWidget);
    });

    testWidgets('does not render key when not available', (WidgetTester tester) async {
      final songWithoutKey = mockSong.copyWith(ourKey: null);

      await pumpAppWidget(
        tester,
        CompactSongCard(song: songWithoutKey),
      );

      expect(find.text('D'), findsNothing);
    });

    testWidgets('does not render BPM when not available', (WidgetTester tester) async {
      final songWithoutBpm = mockSong.copyWith(ourBPM: null);

      await pumpAppWidget(
        tester,
        CompactSongCard(song: songWithoutBpm),
      );

      expect(find.text('BPM'), findsNothing);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      await pumpAppWidget(
        tester,
        CompactSongCard(
          song: mockSong,
          onTap: () => wasTapped = true,
        ),
      );

      await tester.tap(find.text('Compact Song'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('renders as Card widget', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        CompactSongCard(song: mockSong),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders as ListTile', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        CompactSongCard(song: mockSong),
      );

      expect(find.byType(ListTile), findsOneWidget);
    });
  });
}
