import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/link_chip.dart';
import 'package:flutter_repsync_app/models/link.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('LinkChip', () {
    testWidgets('renders link chip with type label', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(find.text('spotify'), findsOneWidget);
    });

    testWidgets('renders link chip with custom title', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/test',
        title: 'My Song',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(find.text('My Song'), findsOneWidget);
    });

    testWidgets('renders Spotify icon for Spotify link', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(findIcon(Icons.play_circle), findsOneWidget);
    });

    testWidgets('renders video icon for YouTube link', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeYoutubeOriginal,
        url: 'https://youtube.com/watch?v=test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(findIcon(Icons.video_library), findsOneWidget);
    });

    testWidgets('renders video icon for YouTube cover link', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeYoutubeCover,
        url: 'https://youtube.com/watch?v=test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(findIcon(Icons.video_library), findsOneWidget);
    });

    testWidgets('renders description icon for tabs link', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeTabs,
        url: 'https://example.com/tabs',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(findIcon(Icons.description), findsOneWidget);
    });

    testWidgets('renders music icon for drums link', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeDrums,
        url: 'https://example.com/drums',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(findIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('renders music icon for chords link', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeChords,
        url: 'https://example.com/chords',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(findIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('renders link icon for unknown type', (WidgetTester tester) async {
      final link = Link(
        type: 'unknown_type',
        url: 'https://example.com',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(findIcon(Icons.link), findsOneWidget);
    });

    testWidgets('renders delete icon when showDelete is true', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(
          link: link,
          showDelete: true,
        ),
      );

      expect(findIcon(Icons.close), findsOneWidget);
    });

    testWidgets('does not render delete icon when showDelete is false', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(
          link: link,
          showDelete: false,
        ),
      );

      verifyNotFound(findIcon(Icons.close));
    });

    testWidgets('calls onDelete when delete icon is tapped', (WidgetTester tester) async {
      bool wasDeleted = false;
      final link = Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(
          link: link,
          showDelete: true,
          onDelete: () => wasDeleted = true,
        ),
      );

      await tester.tap(findIcon(Icons.close));
      await tester.pump();

      expect(wasDeleted, isTrue);
    });

    testWidgets('calls onTap when chip is tapped', (WidgetTester tester) async {
      bool wasTapped = false;
      final link = Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(
          link: link,
          onTap: () => wasTapped = true,
        ),
      );

      await tester.tap(find.text('spotify'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('renders as Chip widget', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(link: link),
      );

      expect(find.byType(Chip), findsOneWidget);
    });

    testWidgets('renders with selected background when isSelected is true', (WidgetTester tester) async {
      final link = Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/test',
      );

      await pumpAppWidget(
        tester,
        LinkChip(
          link: link,
          isSelected: true,
          selectable: true,
        ),
      );

      // Chip should render with selection state
      expect(find.byType(Chip), findsOneWidget);
    });
  });

  group('LinkChipRow', () {
    testWidgets('renders empty when no links', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LinkChipRow(links: []),
      );

      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('renders multiple link chips', (WidgetTester tester) async {
      final links = [
        Link(type: Link.typeSpotify, url: 'https://spotify.com/1'),
        Link(type: Link.typeYoutubeOriginal, url: 'https://youtube.com/1'),
        Link(type: Link.typeTabs, url: 'https://tabs.com/1'),
      ];

      await pumpAppWidget(
        tester,
        LinkChipRow(links: links),
      );

      expect(find.text('spotify'), findsOneWidget);
      expect(find.text('youtube_original'), findsOneWidget);
      expect(find.text('tabs'), findsOneWidget);
    });

    testWidgets('renders as Wrap widget', (WidgetTester tester) async {
      final links = [
        Link(type: Link.typeSpotify, url: 'https://spotify.com/1'),
      ];

      await pumpAppWidget(
        tester,
        LinkChipRow(links: links),
      );

      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('calls onTap for individual link', (WidgetTester tester) async {
      Link? tappedLink;
      final links = [
        Link(type: Link.typeSpotify, url: 'https://spotify.com/1'),
      ];

      await pumpAppWidget(
        tester,
        LinkChipRow(
          links: links,
          onTap: (link) => tappedLink = link,
        ),
      );

      await tester.tap(find.text('spotify'));
      await tester.pump();

      expect(tappedLink, isNotNull);
      expect(tappedLink?.type, equals(Link.typeSpotify));
    });

    testWidgets('calls onDelete for individual link', (WidgetTester tester) async {
      Link? deletedLink;
      final links = [
        Link(type: Link.typeSpotify, url: 'https://spotify.com/1'),
      ];

      await pumpAppWidget(
        tester,
        LinkChipRow(
          links: links,
          showDelete: true,
          onDelete: (link) => deletedLink = link,
        ),
      );

      await tester.tap(findIcon(Icons.close));
      await tester.pump();

      expect(deletedLink, isNotNull);
      expect(deletedLink?.type, equals(Link.typeSpotify));
    });
  });
}
