import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/link.dart';

void main() {
  group('Link Model', () {
    group('Constructor', () {
      test('creates Link with required fields', () {
        final link = Link(
          type: Link.typeYoutubeOriginal,
          url: 'https://youtube.com/watch?v=test',
        );

        expect(link.type, Link.typeYoutubeOriginal);
        expect(link.url, 'https://youtube.com/watch?v=test');
        expect(link.title, isNull);
      });

      test('creates Link with all fields', () {
        final link = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/test123',
          title: 'Test Song on Spotify',
        );

        expect(link.type, Link.typeSpotify);
        expect(link.url, 'https://open.spotify.com/track/test123');
        expect(link.title, 'Test Song on Spotify');
      });
    });

    group('Type Constants', () {
      test('typeYoutubeOriginal constant', () {
        expect(Link.typeYoutubeOriginal, 'youtube_original');
      });

      test('typeYoutubeCover constant', () {
        expect(Link.typeYoutubeCover, 'youtube_cover');
      });

      test('typeSpotify constant', () {
        expect(Link.typeSpotify, 'spotify');
      });

      test('typeTabs constant', () {
        expect(Link.typeTabs, 'tabs');
      });

      test('typeDrums constant', () {
        expect(Link.typeDrums, 'drums');
      });

      test('typeChords constant', () {
        expect(Link.typeChords, 'chords');
      });

      test('typeOther constant', () {
        expect(Link.typeOther, 'other');
      });
    });

    group('fromJson', () {
      test('parses complete JSON data correctly', () {
        final json = {
          'type': 'youtube_original',
          'url': 'https://youtube.com/watch?v=complete',
          'title': 'Complete Link',
        };

        final link = Link.fromJson(json);

        expect(link.type, 'youtube_original');
        expect(link.url, 'https://youtube.com/watch?v=complete');
        expect(link.title, 'Complete Link');
      });

      test('parses JSON without title', () {
        final json = {
          'type': 'spotify',
          'url': 'https://open.spotify.com/track/notitle',
        };

        final link = Link.fromJson(json);

        expect(link.type, 'spotify');
        expect(link.url, 'https://open.spotify.com/track/notitle');
        expect(link.title, isNull);
      });

      test('handles null values with defaults', () {
        final json = {
          'type': null,
          'url': null,
          'title': null,
        };

        final link = Link.fromJson(json);

        expect(link.type, 'other'); // default type
        expect(link.url, '');
        expect(link.title, isNull);
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final link = Link.fromJson(json);

        expect(link.type, 'other'); // default type
        expect(link.url, '');
      });

      test('handles missing type with default other', () {
        final json = {
          'url': 'https://example.com',
        };

        final link = Link.fromJson(json);

        expect(link.type, 'other');
        expect(link.url, 'https://example.com');
      });

      test('handles missing url with empty string default', () {
        final json = {
          'type': 'tabs',
        };

        final link = Link.fromJson(json);

        expect(link.type, 'tabs');
        expect(link.url, '');
      });

      test('parses all link types correctly', () {
        final types = [
          Link.typeYoutubeOriginal,
          Link.typeYoutubeCover,
          Link.typeSpotify,
          Link.typeTabs,
          Link.typeDrums,
          Link.typeChords,
          Link.typeOther,
        ];

        for (final type in types) {
          final json = {
            'type': type,
            'url': 'https://example.com/$type',
          };

          final link = Link.fromJson(json);

          expect(link.type, type, reason: 'Failed for type: $type');
        }
      });
    });

    group('toJson', () {
      test('serializes complete link to JSON', () {
        final link = Link(
          type: Link.typeYoutubeOriginal,
          url: 'https://youtube.com/watch?v=serialize',
          title: 'Serialized Link',
        );

        final json = link.toJson();

        expect(json['type'], Link.typeYoutubeOriginal);
        expect(json['url'], 'https://youtube.com/watch?v=serialize');
        expect(json['title'], 'Serialized Link');
      });

      test('serializes link without title', () {
        final link = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/notitle',
        );

        final json = link.toJson();

        expect(json['type'], Link.typeSpotify);
        expect(json['url'], 'https://open.spotify.com/track/notitle');
        expect(json['title'], isNull);
      });

      test('toJson and fromJson are inverses', () {
        final originalLink = Link(
          type: Link.typeChords,
          url: 'https://chords.com/song/inverse',
          title: 'Inverse Link',
        );

        final json = originalLink.toJson();
        final restoredLink = Link.fromJson(json);

        expect(restoredLink.type, originalLink.type);
        expect(restoredLink.url, originalLink.url);
        expect(restoredLink.title, originalLink.title);
      });

      test('toJson preserves null title', () {
        final link = Link(
          type: Link.typeDrums,
          url: 'https://drums.com/track',
        );

        final json = link.toJson();

        expect(json['type'], Link.typeDrums);
        expect(json['url'], 'https://drums.com/track');
        expect(json['title'], isNull);
      });
    });

    group('Edge Cases', () {
      test('handles empty string url', () {
        final link = Link(
          type: Link.typeOther,
          url: '',
        );

        expect(link.url, '');
      });

      test('handles empty string title', () {
        final link = Link(
          type: Link.typeOther,
          url: 'https://example.com',
          title: '',
        );

        expect(link.title, '');
      });

      test('handles very long url', () {
        final longUrl = 'https://example.com/' + ('a' * 5000);
        final link = Link(
          type: Link.typeOther,
          url: longUrl,
        );

        expect(link.url.length, greaterThan(5000));
      });

      test('handles very long title', () {
        final longTitle = 't' * 5000;
        final link = Link(
          type: Link.typeOther,
          url: 'https://example.com',
          title: longTitle,
        );

        expect(link.title!.length, 5000);
      });

      test('handles special characters in url', () {
        final link = Link(
          type: Link.typeYoutubeOriginal,
          url: 'https://youtube.com/watch?v=test&list=PL123&index=1',
        );

        expect(link.url, contains('&'));
        expect(link.url, contains('list='));
      });

      test('handles special characters in title', () {
        final link = Link(
          type: Link.typeOther,
          url: 'https://example.com',
          title: 'Title with "quotes" and \'apostrophes\' & more',
        );

        expect(link.title, contains('"'));
        expect(link.title, contains('&'));
      });

      test('handles unicode characters in title', () {
        final link = Link(
          type: Link.typeOther,
          url: 'https://example.com',
          title: 'Title 日本語 with emoji 🎵🎸',
        );

        expect(link.title, contains('日本語'));
        expect(link.title, contains('🎵'));
      });

      test('handles URL with query parameters', () {
        final link = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/abc123?si=xyz789&context=playlist',
          title: 'Spotify with params',
        );

        expect(link.url, contains('?'));
        expect(link.url, contains('si='));
        expect(link.url, contains('context='));
      });

      test('handles different URL schemes', () {
        final urls = [
          'https://youtube.com/watch?v=test',
          'http://example.com/http',
          'ftp://files.example.com/file',
        ];

        for (final url in urls) {
          final link = Link(
            type: Link.typeOther,
            url: url,
          );

          expect(link.url, url, reason: 'Failed for URL: $url');
        }
      });
    });

    group('Type-specific Links', () {
      test('creates YouTube Original link', () {
        final link = Link(
          type: Link.typeYoutubeOriginal,
          url: 'https://youtube.com/watch?v=original',
          title: 'Original Version',
        );

        expect(link.type, Link.typeYoutubeOriginal);
        expect(link.url, contains('youtube.com'));
      });

      test('creates YouTube Cover link', () {
        final link = Link(
          type: Link.typeYoutubeCover,
          url: 'https://youtube.com/watch?v=cover',
          title: 'Cover Version',
        );

        expect(link.type, Link.typeYoutubeCover);
        expect(link.url, contains('youtube.com'));
      });

      test('creates Spotify link', () {
        final link = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/spotify123',
          title: 'On Spotify',
        );

        expect(link.type, Link.typeSpotify);
        expect(link.url, contains('spotify.com'));
      });

      test('creates Tabs link', () {
        final link = Link(
          type: Link.typeTabs,
          url: 'https://tabs.ultimate-guitar.com/tab/song',
          title: 'Guitar Tabs',
        );

        expect(link.type, Link.typeTabs);
      });

      test('creates Drums link', () {
        final link = Link(
          type: Link.typeDrums,
          url: 'https://drums.example.com/sheet',
          title: 'Drum Sheet',
        );

        expect(link.type, Link.typeDrums);
      });

      test('creates Chords link', () {
        final link = Link(
          type: Link.typeChords,
          url: 'https://chords.example.com/song',
          title: 'Song Chords',
        );

        expect(link.type, Link.typeChords);
      });

      test('creates Other link', () {
        final link = Link(
          type: Link.typeOther,
          url: 'https://misc.example.com/resource',
          title: 'Misc Resource',
        );

        expect(link.type, Link.typeOther);
      });
    });

    group('Equality and Identity', () {
      test('two links with same values are equal in content', () {
        final link1 = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/same',
          title: 'Same Link',
        );

        final link2 = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/same',
          title: 'Same Link',
        );

        expect(link1.type, link2.type);
        expect(link1.url, link2.url);
        expect(link1.title, link2.title);
      });

      test('two links with different types are different', () {
        final link1 = Link(
          type: Link.typeYoutubeOriginal,
          url: 'https://youtube.com/watch?v=same',
        );

        final link2 = Link(
          type: Link.typeSpotify,
          url: 'https://youtube.com/watch?v=same',
        );

        expect(link1.type, isNot(link2.type));
      });

      test('two links with different urls are different', () {
        final link1 = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/first',
        );

        final link2 = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/second',
        );

        expect(link1.url, isNot(link2.url));
      });

      test('two links with different titles are different', () {
        final link1 = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/same',
          title: 'First Title',
        );

        final link2 = Link(
          type: Link.typeSpotify,
          url: 'https://open.spotify.com/track/same',
          title: 'Second Title',
        );

        expect(link1.title, isNot(link2.title));
      });
    });
  });
}
