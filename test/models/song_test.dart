import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/link.dart';

void main() {
  group('Song Model', () {
    // Test data
    final testDate = DateTime(2024, 1, 15, 10, 30, 0);
    final testLinks = [
      Link(type: Link.typeYoutubeOriginal, url: 'https://youtube.com/watch?v=test1'),
      Link(type: Link.typeSpotify, url: 'https://open.spotify.com/track/test1', title: 'Test Song'),
    ];
    final testTags = ['rock', 'classic', 'upbeat'];

    group('Constructor', () {
      test('creates Song with all required fields', () {
        final song = Song(
          id: 'test-id-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.id, 'test-id-1');
        expect(song.title, 'Test Song');
        expect(song.artist, 'Test Artist');
        expect(song.originalKey, isNull);
        expect(song.originalBPM, isNull);
        expect(song.ourKey, isNull);
        expect(song.ourBPM, isNull);
        expect(song.links, isEmpty);
        expect(song.notes, isNull);
        expect(song.tags, isEmpty);
        expect(song.bandId, isNull);
        expect(song.spotifyUrl, isNull);
        expect(song.createdAt, testDate);
        expect(song.updatedAt, testDate);
      });

      test('creates Song with all optional fields', () {
        final song = Song(
          id: 'test-id-2',
          title: 'Complete Song',
          artist: 'Complete Artist',
          originalKey: 'C Major',
          originalBPM: 120,
          ourKey: 'D Major',
          ourBPM: 125,
          links: testLinks,
          notes: 'Test notes for the song',
          tags: testTags,
          bandId: 'band-123',
          spotifyUrl: 'https://open.spotify.com/track/complete',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.id, 'test-id-2');
        expect(song.title, 'Complete Song');
        expect(song.artist, 'Complete Artist');
        expect(song.originalKey, 'C Major');
        expect(song.originalBPM, 120);
        expect(song.ourKey, 'D Major');
        expect(song.ourBPM, 125);
        expect(song.links, equals(testLinks));
        expect(song.notes, 'Test notes for the song');
        expect(song.tags, equals(testTags));
        expect(song.bandId, 'band-123');
        expect(song.spotifyUrl, 'https://open.spotify.com/track/complete');
        expect(song.createdAt, testDate);
        expect(song.updatedAt, testDate);
      });
    });

    group('fromJson', () {
      test('parses complete JSON data correctly', () {
        final json = {
          'id': 'test-id-3',
          'title': 'JSON Song',
          'artist': 'JSON Artist',
          'originalKey': 'E Minor',
          'originalBPM': 140,
          'ourKey': 'F Minor',
          'ourBPM': 145,
          'links': [
            {'type': 'youtube_original', 'url': 'https://youtube.com/watch?v=json1'},
            {'type': 'spotify', 'url': 'https://spotify.com/track/json1', 'title': 'JSON Song'},
          ],
          'notes': 'Notes from JSON',
          'tags': ['jazz', 'smooth'],
          'bandId': 'band-json-123',
          'spotifyUrl': 'https://spotify.com/track/json1',
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final song = Song.fromJson(json);

        expect(song.id, 'test-id-3');
        expect(song.title, 'JSON Song');
        expect(song.artist, 'JSON Artist');
        expect(song.originalKey, 'E Minor');
        expect(song.originalBPM, 140);
        expect(song.ourKey, 'F Minor');
        expect(song.ourBPM, 145);
        expect(song.links.length, 2);
        expect(song.links.first.type, 'youtube_original');
        expect(song.notes, 'Notes from JSON');
        expect(song.tags, equals(['jazz', 'smooth']));
        expect(song.bandId, 'band-json-123');
        expect(song.spotifyUrl, 'https://spotify.com/track/json1');
        expect(song.createdAt, testDate);
        expect(song.updatedAt, testDate);
      });

      test('handles null values with defaults', () {
        final json = {
          'id': null,
          'title': null,
          'artist': null,
          'originalKey': null,
          'originalBPM': null,
          'ourKey': null,
          'ourBPM': null,
          'links': null,
          'notes': null,
          'tags': null,
          'bandId': null,
          'spotifyUrl': null,
          'createdAt': null,
          'updatedAt': null,
        };

        final song = Song.fromJson(json);

        expect(song.id, '');
        expect(song.title, '');
        expect(song.artist, '');
        expect(song.originalKey, isNull);
        expect(song.originalBPM, isNull);
        expect(song.ourKey, isNull);
        expect(song.ourBPM, isNull);
        expect(song.links, isEmpty);
        expect(song.notes, isNull);
        expect(song.tags, isEmpty);
        expect(song.bandId, isNull);
        expect(song.spotifyUrl, isNull);
        expect(song.createdAt, isNotNull);
        expect(song.updatedAt, isNotNull);
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final song = Song.fromJson(json);

        expect(song.id, '');
        expect(song.title, '');
        expect(song.artist, '');
        expect(song.links, isEmpty);
        expect(song.tags, isEmpty);
        expect(song.createdAt, isNotNull);
        expect(song.updatedAt, isNotNull);
      });

      test('handles empty list for links', () {
        final json = {
          'id': 'test-id',
          'title': 'Test',
          'artist': 'Artist',
          'links': [],
          'tags': [],
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final song = Song.fromJson(json);

        expect(song.links, isEmpty);
        expect(song.tags, isEmpty);
      });

      test('parses links correctly', () {
        final json = {
          'id': 'test-id',
          'title': 'Test',
          'artist': 'Artist',
          'links': [
            {'type': 'youtube_cover', 'url': 'https://youtube.com/cover', 'title': 'Cover Version'},
            {'type': 'tabs', 'url': 'https://tabs.com/song'},
          ],
          'tags': ['rock'],
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final song = Song.fromJson(json);

        expect(song.links.length, 2);
        expect(song.links[0].type, 'youtube_cover');
        expect(song.links[0].url, 'https://youtube.com/cover');
        expect(song.links[0].title, 'Cover Version');
        expect(song.links[1].type, 'tabs');
        expect(song.links[1].url, 'https://tabs.com/song');
        expect(song.links[1].title, isNull);
      });
    });

    group('toJson', () {
      test('serializes complete song to JSON', () {
        final song = Song(
          id: 'test-id-4',
          title: 'Serialize Song',
          artist: 'Serialize Artist',
          originalKey: 'G Major',
          originalBPM: 100,
          ourKey: 'A Major',
          ourBPM: 105,
          links: testLinks,
          notes: 'Serialization test notes',
          tags: testTags,
          bandId: 'band-serialize',
          spotifyUrl: 'https://spotify.com/serialize',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final json = song.toJson();

        expect(json['id'], 'test-id-4');
        expect(json['title'], 'Serialize Song');
        expect(json['artist'], 'Serialize Artist');
        expect(json['originalKey'], 'G Major');
        expect(json['originalBPM'], 100);
        expect(json['ourKey'], 'A Major');
        expect(json['ourBPM'], 105);
        expect(json['links'], isA<List>());
        expect(json['links'].length, 2);
        expect(json['notes'], 'Serialization test notes');
        expect(json['tags'], equals(testTags));
        expect(json['bandId'], 'band-serialize');
        expect(json['spotifyUrl'], 'https://spotify.com/serialize');
        expect(json['createdAt'], testDate.toIso8601String());
        expect(json['updatedAt'], testDate.toIso8601String());
      });

      test('serializes song with null values', () {
        final song = Song(
          id: 'test-id-5',
          title: 'Null Song',
          artist: 'Null Artist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final json = song.toJson();

        expect(json['id'], 'test-id-5');
        expect(json['title'], 'Null Song');
        expect(json['artist'], 'Null Artist');
        expect(json['originalKey'], isNull);
        expect(json['originalBPM'], isNull);
        expect(json['ourKey'], isNull);
        expect(json['ourBPM'], isNull);
        expect(json['links'], isA<List>());
        expect(json['links'].length, 0);
        expect(json['notes'], isNull);
        expect(json['tags'], isA<List>());
        expect(json['tags'].length, 0);
        expect(json['bandId'], isNull);
        expect(json['spotifyUrl'], isNull);
      });

      test('toJson and fromJson are inverses', () {
        final originalSong = Song(
          id: 'test-id-6',
          title: 'Inverse Song',
          artist: 'Inverse Artist',
          originalKey: 'B Minor',
          originalBPM: 130,
          ourKey: 'C Minor',
          ourBPM: 135,
          links: testLinks,
          notes: 'Inverse test notes',
          tags: testTags,
          bandId: 'band-inverse',
          spotifyUrl: 'https://spotify.com/inverse',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final json = originalSong.toJson();
        final restoredSong = Song.fromJson(json);

        expect(restoredSong.id, originalSong.id);
        expect(restoredSong.title, originalSong.title);
        expect(restoredSong.artist, originalSong.artist);
        expect(restoredSong.originalKey, originalSong.originalKey);
        expect(restoredSong.originalBPM, originalSong.originalBPM);
        expect(restoredSong.ourKey, originalSong.ourKey);
        expect(restoredSong.ourBPM, originalSong.ourBPM);
        expect(restoredSong.links.length, originalSong.links.length);
        expect(restoredSong.notes, originalSong.notes);
        expect(restoredSong.tags, originalSong.tags);
        expect(restoredSong.bandId, originalSong.bandId);
        expect(restoredSong.spotifyUrl, originalSong.spotifyUrl);
        expect(restoredSong.createdAt, originalSong.createdAt);
        expect(restoredSong.updatedAt, originalSong.updatedAt);
      });
    });

    group('copyWith', () {
      test('returns a copy with all fields unchanged when no arguments', () {
        final originalSong = Song(
          id: 'test-id-7',
          title: 'Original Song',
          artist: 'Original Artist',
          originalKey: 'D Minor',
          originalBPM: 110,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSong = originalSong.copyWith();

        expect(copiedSong.id, originalSong.id);
        expect(copiedSong.title, originalSong.title);
        expect(copiedSong.artist, originalSong.artist);
        expect(copiedSong.originalKey, originalSong.originalKey);
        expect(copiedSong.originalBPM, originalSong.originalBPM);
        expect(copiedSong.createdAt, originalSong.createdAt);
        expect(copiedSong.updatedAt, originalSong.updatedAt);
        expect(copiedSong, isNot(same(originalSong)));
      });

      test('updates title field', () {
        final originalSong = Song(
          id: 'test-id-8',
          title: 'Old Title',
          artist: 'Artist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSong = originalSong.copyWith(title: 'New Title');

        expect(copiedSong.title, 'New Title');
        expect(copiedSong.artist, 'Artist');
      });

      test('updates artist field', () {
        final originalSong = Song(
          id: 'test-id-9',
          title: 'Title',
          artist: 'Old Artist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSong = originalSong.copyWith(artist: 'New Artist');

        expect(copiedSong.artist, 'New Artist');
        expect(copiedSong.title, 'Title');
      });

      test('updates multiple fields', () {
        final originalSong = Song(
          id: 'test-id-10',
          title: 'Title',
          artist: 'Artist',
          originalKey: 'Old Key',
          originalBPM: 100,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final newDate = DateTime(2024, 6, 15);
        final copiedSong = originalSong.copyWith(
          title: 'New Title',
          originalKey: 'New Key',
          originalBPM: 150,
          updatedAt: newDate,
        );

        expect(copiedSong.title, 'New Title');
        expect(copiedSong.originalKey, 'New Key');
        expect(copiedSong.originalBPM, 150);
        expect(copiedSong.updatedAt, newDate);
        expect(copiedSong.artist, 'Artist');
        expect(copiedSong.originalBPM, 150);
      });

      test('updates links field', () {
        final originalSong = Song(
          id: 'test-id-11',
          title: 'Title',
          artist: 'Artist',
          links: [],
          createdAt: testDate,
          updatedAt: testDate,
        );

        final newLinks = [
          Link(type: Link.typeChords, url: 'https://chords.com/song'),
        ];
        final copiedSong = originalSong.copyWith(links: newLinks);

        expect(copiedSong.links, equals(newLinks));
        expect(copiedSong.links.length, 1);
      });

      test('updates tags field', () {
        final originalSong = Song(
          id: 'test-id-12',
          title: 'Title',
          artist: 'Artist',
          tags: ['old'],
          createdAt: testDate,
          updatedAt: testDate,
        );

        final newTags = ['new', 'updated'];
        final copiedSong = originalSong.copyWith(tags: newTags);

        expect(copiedSong.tags, equals(newTags));
      });

      test('updates nullable fields to null', () {
        final originalSong = Song(
          id: 'test-id-13',
          title: 'Title',
          artist: 'Artist',
          originalKey: 'Some Key',
          notes: 'Some notes',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSong = originalSong.copyWith(
          originalKey: null,
          notes: null,
        );

        expect(copiedSong.originalKey, isNull);
        expect(copiedSong.notes, isNull);
      });

      test('updates bandId and spotifyUrl', () {
        final originalSong = Song(
          id: 'test-id-14',
          title: 'Title',
          artist: 'Artist',
          bandId: 'old-band',
          spotifyUrl: 'https://spotify.com/old',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSong = originalSong.copyWith(
          bandId: 'new-band',
          spotifyUrl: 'https://spotify.com/new',
        );

        expect(copiedSong.bandId, 'new-band');
        expect(copiedSong.spotifyUrl, 'https://spotify.com/new');
      });
    });

    group('Edge Cases', () {
      test('handles empty string title and artist', () {
        final song = Song(
          id: 'test-id-15',
          title: '',
          artist: '',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.title, '');
        expect(song.artist, '');
      });

      test('handles very long strings', () {
        final longString = 'a' * 10000;
        final song = Song(
          id: 'test-id-16',
          title: longString,
          artist: longString,
          notes: longString,
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.title.length, 10000);
        expect(song.artist.length, 10000);
        expect(song.notes!.length, 10000);
      });

      test('handles special characters in strings', () {
        final song = Song(
          id: 'test-id-17',
          title: 'Song with "quotes" and \'apostrophes\'',
          artist: 'Artist & Band ft. Someone',
          notes: 'Notes with special chars: @#\$%^&*()',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.title, contains('quotes'));
        expect(song.artist, contains('&'));
        expect(song.notes, contains('@#\$%^&*()'));
      });

      test('handles unicode characters', () {
        final song = Song(
          id: 'test-id-18',
          title: 'Song 日本語',
          artist: 'アーティスト',
          notes: 'Notes with emoji 🎵🎸',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.title, contains('日本語'));
        expect(song.artist, contains('アーティスト'));
        expect(song.notes, contains('🎵'));
      });

      test('handles empty tags list', () {
        final song = Song(
          id: 'test-id-19',
          title: 'Title',
          artist: 'Artist',
          tags: [],
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.tags, isEmpty);
      });

      test('handles many tags', () {
        final manyTags = List.generate(100, (i) => 'tag$i');
        final song = Song(
          id: 'test-id-20',
          title: 'Title',
          artist: 'Artist',
          tags: manyTags,
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.tags.length, 100);
        expect(song.tags.first, 'tag0');
        expect(song.tags.last, 'tag99');
      });
    });

    group('Default Values', () {
      test('default links is empty list', () {
        final song = Song(
          id: 'test-id',
          title: 'Title',
          artist: 'Artist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.links, equals([]));
      });

      test('default tags is empty list', () {
        final song = Song(
          id: 'test-id',
          title: 'Title',
          artist: 'Artist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.tags, equals([]));
      });

      test('fromJson default links is empty list when null', () {
        final json = {
          'id': 'test-id',
          'title': 'Title',
          'artist': 'Artist',
          'links': null,
          'tags': null,
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final song = Song.fromJson(json);

        expect(song.links, equals([]));
        expect(song.tags, equals([]));
      });
    });
  });
}
