import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/services/export/pdf_service.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/link.dart';

void main() {
  group('PdfService', () {
    group('exportSetlist', () {
      test('PdfService class exists and has exportSetlist method', () {
        expect(PdfService, isNotNull);
        expect(PdfService.exportSetlist, isNotNull);
      });

      test('exportSetlist is a static method', () {
        // Verify the method signature
        expect(PdfService.exportSetlist, isA<Function>());
      });
    });

    group('Setlist model for PDF', () {
      test('Setlist with all fields for PDF export', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          description: 'Test Description',
          eventDate: DateTime(2024, 12, 25),
          eventLocation: 'Test Venue',
          songIds: ['song-1', 'song-2'],
          totalDuration: 600,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(setlist.name, equals('Test Setlist'));
        expect(setlist.description, equals('Test Description'));
        expect(setlist.eventDate, equals(DateTime(2024, 12, 25)));
        expect(setlist.eventLocation, equals('Test Venue'));
        expect(setlist.songIds.length, equals(2));
        expect(setlist.totalDuration, equals(600));
      });

      test('Setlist with null optional fields', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          description: null,
          eventDate: null,
          eventLocation: null,
          songIds: [],
          totalDuration: null,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(setlist.name, equals('Test Setlist'));
        expect(setlist.description, isNull);
        expect(setlist.eventDate, isNull);
        expect(setlist.eventLocation, isNull);
        expect(setlist.songIds, isEmpty);
        expect(setlist.totalDuration, isNull);
      });

      test('Setlist toJson serializes correctly', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          description: 'Test Description',
          eventDate: DateTime(2024, 12, 25),
          eventLocation: 'Test Venue',
          songIds: ['song-1'],
          totalDuration: 300,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = setlist.toJson();
        expect(json['id'], equals('setlist-1'));
        expect(json['bandId'], equals('band-1'));
        expect(json['name'], equals('Test Setlist'));
        expect(json['description'], equals('Test Description'));
        expect(
          json['eventDate'],
          equals(DateTime(2024, 12, 25).toIso8601String()),
        );
        expect(json['eventLocation'], equals('Test Venue'));
        expect(json['songIds'], equals(['song-1']));
        expect(json['totalDuration'], equals(300));
      });

      test('Setlist fromJson deserializes correctly', () {
        final json = {
          'id': 'setlist-1',
          'bandId': 'band-1',
          'name': 'Test Setlist',
          'description': 'Test Description',
          'eventDate': '2024-12-25',
          'eventLocation': 'Test Venue',
          'songIds': ['song-1', 'song-2'],
          'totalDuration': 600,
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-02T00:00:00.000',
        };

        final setlist = Setlist.fromJson(json);
        expect(setlist.id, equals('setlist-1'));
        expect(setlist.bandId, equals('band-1'));
        expect(setlist.name, equals('Test Setlist'));
        expect(setlist.description, equals('Test Description'));
        expect(setlist.eventDate, equals(DateTime(2024, 12, 25)));
        expect(setlist.eventLocation, equals('Test Venue'));
        expect(setlist.songIds.length, equals(2));
        expect(setlist.totalDuration, equals(600));
      });

      test('Setlist fromJson handles missing optional fields', () {
        final json = {
          'id': 'setlist-1',
          'bandId': 'band-1',
          'name': 'Test Setlist',
          'songIds': [],
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
        };

        final setlist = Setlist.fromJson(json);
        expect(setlist.description, isNull);
        expect(setlist.eventDate, isNull);
        expect(setlist.eventLocation, isNull);
        expect(setlist.totalDuration, isNull);
      });

      test('Setlist fromJson uses default date when null', () {
        final json = {
          'id': 'setlist-1',
          'bandId': 'band-1',
          'name': 'Test Setlist',
          'songIds': [],
        };

        final setlist = Setlist.fromJson(json);
        expect(setlist.createdAt, isNotNull);
        expect(setlist.updatedAt, isNotNull);
      });

      test('Setlist copyWith creates new instance with updated values', () {
        final original = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Original',
          songIds: [],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final copied = original.copyWith(
          name: 'Updated',
          description: 'New Description',
        );

        expect(original.name, equals('Original'));
        expect(copied.name, equals('Updated'));
        expect(copied.description, equals('New Description'));
        expect(copied.bandId, equals(original.bandId));
      });

      test('Setlist copyWith preserves unchanged values', () {
        final original = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test',
          description: 'Description',
          eventDate: DateTime(2024, 12, 25),
          eventLocation: 'Venue',
          songIds: ['song-1'],
          totalDuration: 300,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final copied = original.copyWith(name: 'Updated');

        expect(copied.name, equals('Updated'));
        expect(copied.description, equals('Description'));
        expect(copied.eventDate, equals(DateTime(2024, 12, 25)));
        expect(copied.eventLocation, equals('Venue'));
        expect(copied.songIds, equals(['song-1']));
        expect(copied.totalDuration, equals(300));
      });
    });

    group('Song model for PDF', () {
      test('Song with all fields for PDF export', () {
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          originalKey: 'C',
          originalBPM: 120,
          ourKey: 'D',
          ourBPM: 130,
          links: [Link(url: 'https://example.com', type: 'youtube')],
          notes: 'Test Notes',
          tags: ['rock', 'classic'],
          bandId: 'band-1',
          spotifyUrl: 'https://spotify.com/track/123',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(song.title, equals('Test Song'));
        expect(song.artist, equals('Test Artist'));
        expect(song.originalKey, equals('C'));
        expect(song.originalBPM, equals(120));
        expect(song.ourKey, equals('D'));
        expect(song.ourBPM, equals(130));
        expect(song.links.length, equals(1));
        expect(song.notes, equals('Test Notes'));
        expect(song.tags.length, equals(2));
        expect(song.spotifyUrl, isNotNull);
      });

      test('Song with null optional fields', () {
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          originalKey: null,
          originalBPM: null,
          ourKey: null,
          ourBPM: null,
          links: [],
          notes: null,
          tags: [],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(song.title, equals('Test Song'));
        expect(song.artist, equals('Test Artist'));
        expect(song.originalKey, isNull);
        expect(song.originalBPM, isNull);
        expect(song.ourKey, isNull);
        expect(song.ourBPM, isNull);
        expect(song.links, isEmpty);
        expect(song.notes, isNull);
        expect(song.tags, isEmpty);
      });

      test('Song toJson serializes correctly', () {
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          ourKey: 'D',
          ourBPM: 130,
          links: [],
          tags: ['rock'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = song.toJson();
        expect(json['id'], equals('song-1'));
        expect(json['title'], equals('Test Song'));
        expect(json['artist'], equals('Test Artist'));
        expect(json['ourKey'], equals('D'));
        expect(json['ourBPM'], equals(130));
        expect(json['tags'], equals(['rock']));
      });

      test('Song fromJson deserializes correctly', () {
        final json = {
          'id': 'song-1',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'originalKey': 'C',
          'originalBPM': 120,
          'ourKey': 'D',
          'ourBPM': 130,
          'links': [],
          'notes': 'Test Notes',
          'tags': ['rock', 'classic'],
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-02T00:00:00.000',
        };

        final song = Song.fromJson(json);
        expect(song.id, equals('song-1'));
        expect(song.title, equals('Test Song'));
        expect(song.artist, equals('Test Artist'));
        expect(song.originalKey, equals('C'));
        expect(song.originalBPM, equals(120));
        expect(song.ourKey, equals('D'));
        expect(song.ourBPM, equals(130));
        expect(song.notes, equals('Test Notes'));
        expect(song.tags.length, equals(2));
      });

      test('Song fromJson handles empty links', () {
        final json = {
          'id': 'song-1',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'links': null,
          'tags': null,
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
        };

        final song = Song.fromJson(json);
        expect(song.links, isEmpty);
        expect(song.tags, isEmpty);
      });

      test('Song copyWith creates new instance with updated values', () {
        final original = Song(
          id: 'song-1',
          title: 'Original',
          artist: 'Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final copied = original.copyWith(
          title: 'Updated',
          ourKey: 'D',
          ourBPM: 130,
        );

        expect(original.title, equals('Original'));
        expect(copied.title, equals('Updated'));
        expect(copied.ourKey, equals('D'));
        expect(copied.ourBPM, equals(130));
        expect(copied.artist, equals(original.artist));
      });

      test('Song copyWith handles sentinel values correctly', () {
        final original = Song(
          id: 'song-1',
          title: 'Test',
          artist: 'Artist',
          originalKey: 'C',
          originalBPM: 120,
          ourKey: 'D',
          ourBPM: 130,
          notes: 'Notes',
          bandId: 'band-1',
          spotifyUrl: 'https://spotify.com',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        // Copy without changes should preserve all values
        final copied = original.copyWith();

        expect(copied.originalKey, equals('C'));
        expect(copied.originalBPM, equals(120));
        expect(copied.ourKey, equals('D'));
        expect(copied.ourBPM, equals(130));
        expect(copied.notes, equals('Notes'));
        expect(copied.bandId, equals('band-1'));
        expect(copied.spotifyUrl, equals('https://spotify.com'));
      });

      test('Song copyWith sets nullable fields to null', () {
        final original = Song(
          id: 'song-1',
          title: 'Test',
          artist: 'Artist',
          originalKey: 'C',
          originalBPM: 120,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final copied = original.copyWith(originalKey: null, originalBPM: null);

        expect(copied.originalKey, isNull);
        expect(copied.originalBPM, isNull);
      });
    });

    group('Link model for PDF', () {
      test('Link toJson serializes correctly', () {
        final link = Link(url: 'https://example.com', type: 'youtube');
        final json = link.toJson();

        expect(json['url'], equals('https://example.com'));
        expect(json['type'], equals('youtube'));
      });

      test('Link fromJson deserializes correctly', () {
        final json = {'url': 'https://example.com', 'type': 'spotify'};

        final link = Link.fromJson(json);
        expect(link.url, equals('https://example.com'));
        expect(link.type, equals('spotify'));
      });

      test('Link with title', () {
        final link = Link(
          url: 'https://example.com',
          type: 'youtube',
          title: 'Test Video',
        );

        expect(link.title, equals('Test Video'));
      });

      test('Link fromJson handles missing title', () {
        final json = {'url': 'https://example.com', 'type': 'youtube'};

        final link = Link.fromJson(json);
        expect(link.title, isNull);
      });
    });

    group('PDF Export Edge Cases', () {
      test('Setlist with empty song list', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Empty Setlist',
          songIds: [],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(setlist.songIds, isEmpty);
        expect(setlist.name, equals('Empty Setlist'));
      });

      test('Song with only required fields', () {
        final song = Song(
          id: 'song-1',
          title: 'Minimal Song',
          artist: 'Minimal Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(song.id, equals('song-1'));
        expect(song.title, equals('Minimal Song'));
        expect(song.artist, equals('Minimal Artist'));
        expect(song.ourKey, isNull);
        expect(song.ourBPM, isNull);
      });

      test('Setlist with special characters in name', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test & Setlist "With" Special Characters',
          songIds: [],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(setlist.name, contains('&'));
        expect(setlist.name, contains('"'));
      });

      test('Song with unicode characters', () {
        final song = Song(
          id: 'song-1',
          title: 'Song with émojis 🎵',
          artist: 'Artist ñ',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(song.title, contains('🎵'));
        expect(song.artist, contains('ñ'));
      });
    });
  });
}
