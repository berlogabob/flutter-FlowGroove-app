import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/setlist.dart';

void main() {
  group('Setlist Model', () {
    // Test data
    final testDate = DateTime(2024, 5, 10, 18, 0, 0);
    final testSongIds = ['song-1', 'song-2', 'song-3'];

    group('Constructor', () {
      test('creates Setlist with required fields', () {
        final setlist = Setlist(
          id: 'setlist-id-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(setlist.id, 'setlist-id-1');
        expect(setlist.bandId, 'band-1');
        expect(setlist.name, 'Test Setlist');
        expect(setlist.description, isNull);
        expect(setlist.eventDate, isNull);
        expect(setlist.eventLocation, isNull);
        expect(setlist.songIds, isEmpty);
        expect(setlist.totalDuration, isNull);
        expect(setlist.createdAt, testDate);
        expect(setlist.updatedAt, testDate);
      });

      test('creates Setlist with all optional fields', () {
        final setlist = Setlist(
          id: 'setlist-id-2',
          bandId: 'band-2',
          name: 'Complete Setlist',
          description: 'A complete test setlist',
          eventDate: '2024-06-15',
          eventLocation: 'Main Stage Arena',
          songIds: testSongIds,
          totalDuration: 3600,
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(setlist.id, 'setlist-id-2');
        expect(setlist.bandId, 'band-2');
        expect(setlist.name, 'Complete Setlist');
        expect(setlist.description, 'A complete test setlist');
        expect(setlist.eventDate, '2024-06-15');
        expect(setlist.eventLocation, 'Main Stage Arena');
        expect(setlist.songIds.length, 3);
        expect(setlist.totalDuration, 3600);
        expect(setlist.createdAt, testDate);
        expect(setlist.updatedAt, testDate);
      });
    });

    group('fromJson', () {
      test('parses complete JSON data correctly', () {
        final json = {
          'id': 'setlist-id-3',
          'bandId': 'band-3',
          'name': 'JSON Setlist',
          'description': 'Setlist from JSON',
          'eventDate': '2024-07-20',
          'eventLocation': 'JSON Venue',
          'songIds': ['song-a', 'song-b', 'song-c'],
          'totalDuration': 4500,
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final setlist = Setlist.fromJson(json);

        expect(setlist.id, 'setlist-id-3');
        expect(setlist.bandId, 'band-3');
        expect(setlist.name, 'JSON Setlist');
        expect(setlist.description, 'Setlist from JSON');
        expect(setlist.eventDate, '2024-07-20');
        expect(setlist.eventLocation, 'JSON Venue');
        expect(setlist.songIds.length, 3);
        expect(setlist.songIds[0], 'song-a');
        expect(setlist.songIds[1], 'song-b');
        expect(setlist.songIds[2], 'song-c');
        expect(setlist.totalDuration, 4500);
        expect(setlist.createdAt, testDate);
        expect(setlist.updatedAt, testDate);
      });

      test('handles null values with defaults', () {
        final json = {
          'id': null,
          'bandId': null,
          'name': null,
          'description': null,
          'eventDate': null,
          'eventLocation': null,
          'songIds': null,
          'totalDuration': null,
          'createdAt': null,
          'updatedAt': null,
        };

        final setlist = Setlist.fromJson(json);

        expect(setlist.id, '');
        expect(setlist.bandId, '');
        expect(setlist.name, '');
        expect(setlist.description, isNull);
        expect(setlist.eventDate, isNull);
        expect(setlist.eventLocation, isNull);
        expect(setlist.songIds, isEmpty);
        expect(setlist.totalDuration, isNull);
        expect(setlist.createdAt, isNotNull);
        expect(setlist.updatedAt, isNotNull);
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final setlist = Setlist.fromJson(json);

        expect(setlist.id, '');
        expect(setlist.bandId, '');
        expect(setlist.name, '');
        expect(setlist.songIds, isEmpty);
        expect(setlist.createdAt, isNotNull);
        expect(setlist.updatedAt, isNotNull);
      });

      test('handles empty songIds list', () {
        final json = {
          'id': 'setlist-id-4',
          'bandId': 'band-4',
          'name': 'Empty Setlist',
          'songIds': [],
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final setlist = Setlist.fromJson(json);

        expect(setlist.songIds, isEmpty);
      });

      test('parses songIds correctly', () {
        final json = {
          'id': 'setlist-id-5',
          'bandId': 'band-5',
          'name': 'Setlist with Songs',
          'songIds': [
            'song-001',
            'song-002',
            'song-003',
            'song-004',
            'song-005',
          ],
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final setlist = Setlist.fromJson(json);

        expect(setlist.songIds.length, 5);
        expect(setlist.songIds[0], 'song-001');
        expect(setlist.songIds[4], 'song-005');
      });
    });

    group('toJson', () {
      test('serializes complete setlist to JSON', () {
        final setlist = Setlist(
          id: 'setlist-id-6',
          bandId: 'band-6',
          name: 'Serialize Setlist',
          description: 'Setlist for serialization test',
          eventDate: '2024-08-25',
          eventLocation: 'Serialize Venue',
          songIds: testSongIds,
          totalDuration: 5400,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final json = setlist.toJson();

        expect(json['id'], 'setlist-id-6');
        expect(json['bandId'], 'band-6');
        expect(json['name'], 'Serialize Setlist');
        expect(json['description'], 'Setlist for serialization test');
        expect(json['eventDate'], '2024-08-25');
        expect(json['eventLocation'], 'Serialize Venue');
        expect(json['songIds'], isA<List>());
        expect(json['songIds'].length, 3);
        expect(json['totalDuration'], 5400);
        expect(json['createdAt'], testDate.toIso8601String());
        expect(json['updatedAt'], testDate.toIso8601String());
      });

      test('serializes setlist with null values', () {
        final setlist = Setlist(
          id: 'setlist-id-7',
          bandId: 'band-7',
          name: 'Null Setlist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final json = setlist.toJson();

        expect(json['id'], 'setlist-id-7');
        expect(json['bandId'], 'band-7');
        expect(json['name'], 'Null Setlist');
        expect(json['description'], isNull);
        expect(json['eventDate'], isNull);
        expect(json['eventLocation'], isNull);
        expect(json['songIds'], isA<List>());
        expect(json['songIds'].length, 0);
        expect(json['totalDuration'], isNull);
      });

      test('toJson and fromJson are inverses', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-8',
          bandId: 'band-8',
          name: 'Inverse Setlist',
          description: 'Inverse test setlist',
          eventDate: '2024-09-30',
          eventLocation: 'Inverse Venue',
          songIds: testSongIds,
          totalDuration: 2700,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final json = originalSetlist.toJson();
        final restoredSetlist = Setlist.fromJson(json);

        expect(restoredSetlist.id, originalSetlist.id);
        expect(restoredSetlist.bandId, originalSetlist.bandId);
        expect(restoredSetlist.name, originalSetlist.name);
        expect(restoredSetlist.description, originalSetlist.description);
        expect(restoredSetlist.eventDate, originalSetlist.eventDate);
        expect(restoredSetlist.eventLocation, originalSetlist.eventLocation);
        expect(restoredSetlist.songIds.length, originalSetlist.songIds.length);
        expect(restoredSetlist.totalDuration, originalSetlist.totalDuration);
        expect(restoredSetlist.createdAt, originalSetlist.createdAt);
        expect(restoredSetlist.updatedAt, originalSetlist.updatedAt);
      });
    });

    group('copyWith', () {
      test('returns a copy with all fields unchanged when no arguments', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-9',
          bandId: 'band-9',
          name: 'Original Setlist',
          description: 'Original description',
          eventDate: '2024-10-10',
          eventLocation: 'Original Venue',
          songIds: testSongIds,
          totalDuration: 1800,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSetlist = originalSetlist.copyWith();

        expect(copiedSetlist.id, originalSetlist.id);
        expect(copiedSetlist.bandId, originalSetlist.bandId);
        expect(copiedSetlist.name, originalSetlist.name);
        expect(copiedSetlist.description, originalSetlist.description);
        expect(copiedSetlist.eventDate, originalSetlist.eventDate);
        expect(copiedSetlist.eventLocation, originalSetlist.eventLocation);
        expect(copiedSetlist.songIds, originalSetlist.songIds);
        expect(copiedSetlist.totalDuration, originalSetlist.totalDuration);
        expect(copiedSetlist.createdAt, originalSetlist.createdAt);
        expect(copiedSetlist.updatedAt, originalSetlist.updatedAt);
        expect(copiedSetlist, isNot(same(originalSetlist)));
      });

      test('updates name field', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-10',
          bandId: 'band-10',
          name: 'Old Setlist Name',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSetlist = originalSetlist.copyWith(name: 'New Setlist Name');

        expect(copiedSetlist.name, 'New Setlist Name');
        expect(copiedSetlist.bandId, 'band-10');
      });

      test('updates bandId field', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-11',
          bandId: 'old-band',
          name: 'Setlist 11',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSetlist = originalSetlist.copyWith(bandId: 'new-band');

        expect(copiedSetlist.bandId, 'new-band');
      });

      test('updates description field', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-12',
          bandId: 'band-12',
          name: 'Setlist 12',
          description: 'Old description',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSetlist = originalSetlist.copyWith(description: 'New description');

        expect(copiedSetlist.description, 'New description');
      });

      test('updates eventDate field', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-13',
          bandId: 'band-13',
          name: 'Setlist 13',
          eventDate: '2024-01-01',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSetlist = originalSetlist.copyWith(eventDate: '2024-12-31');

        expect(copiedSetlist.eventDate, '2024-12-31');
      });

      test('updates eventLocation field', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-14',
          bandId: 'band-14',
          name: 'Setlist 14',
          eventLocation: 'Old Venue',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSetlist = originalSetlist.copyWith(eventLocation: 'New Venue');

        expect(copiedSetlist.eventLocation, 'New Venue');
      });

      test('updates songIds field', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-15',
          bandId: 'band-15',
          name: 'Setlist 15',
          songIds: [],
          createdAt: testDate,
          updatedAt: testDate,
        );

        final newSongIds = ['new-song-1', 'new-song-2'];
        final copiedSetlist = originalSetlist.copyWith(songIds: newSongIds);

        expect(copiedSetlist.songIds, equals(newSongIds));
        expect(copiedSetlist.songIds.length, 2);
      });

      test('updates totalDuration field', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-16',
          bandId: 'band-16',
          name: 'Setlist 16',
          totalDuration: 1000,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSetlist = originalSetlist.copyWith(totalDuration: 5000);

        expect(copiedSetlist.totalDuration, 5000);
      });

      test('updates multiple fields', () {
        final newDate = DateTime(2024, 11, 11);
        final originalSetlist = Setlist(
          id: 'setlist-id-17',
          bandId: 'band-17',
          name: 'Setlist 17',
          description: 'Description',
          eventDate: '2024-01-01',
          eventLocation: 'Venue',
          totalDuration: 1000,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSetlist = originalSetlist.copyWith(
          name: 'Updated Setlist',
          description: 'Updated description',
          eventDate: '2024-12-31',
          eventLocation: 'Updated Venue',
          totalDuration: 6000,
          updatedAt: newDate,
        );

        expect(copiedSetlist.name, 'Updated Setlist');
        expect(copiedSetlist.description, 'Updated description');
        expect(copiedSetlist.eventDate, '2024-12-31');
        expect(copiedSetlist.eventLocation, 'Updated Venue');
        expect(copiedSetlist.totalDuration, 6000);
        expect(copiedSetlist.updatedAt, newDate);
        expect(copiedSetlist.bandId, 'band-17');
      });

      test('updates nullable fields to null', () {
        final originalSetlist = Setlist(
          id: 'setlist-id-18',
          bandId: 'band-18',
          name: 'Setlist 18',
          description: 'Some description',
          eventDate: '2024-01-01',
          eventLocation: 'Some Venue',
          totalDuration: 1000,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final copiedSetlist = originalSetlist.copyWith(
          description: null,
          eventDate: null,
          eventLocation: null,
          totalDuration: null,
        );

        expect(copiedSetlist.description, isNull);
        expect(copiedSetlist.eventDate, isNull);
        expect(copiedSetlist.eventLocation, isNull);
        expect(copiedSetlist.totalDuration, isNull);
      });
    });

    group('Edge Cases', () {
      test('handles empty string name', () {
        final setlist = Setlist(
          id: 'setlist-id-19',
          bandId: 'band-19',
          name: '',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(setlist.name, '');
      });

      test('handles very long strings', () {
        final longString = 'y' * 5000;
        final setlist = Setlist(
          id: 'setlist-id-20',
          bandId: 'band-20',
          name: longString,
          description: longString,
          eventLocation: longString,
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(setlist.name.length, 5000);
        expect(setlist.description!.length, 5000);
        expect(setlist.eventLocation!.length, 5000);
      });

      test('handles special characters in strings', () {
        final setlist = Setlist(
          id: 'setlist-id-21',
          bandId: 'band-21',
          name: 'Setlist & Show "Night"',
          description: 'Description with special: @#\$%^&*()',
          eventLocation: 'Venue #1 @ Downtown',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(setlist.name, contains('&'));
        expect(setlist.description, contains('@#\$%^&*()'));
        expect(setlist.eventLocation, contains('@'));
      });

      test('handles unicode characters', () {
        final setlist = Setlist(
          id: 'setlist-id-22',
          bandId: 'band-22',
          name: 'セットリスト 音楽',
          description: 'Описание with emoji 🎵🎤🎸',
          eventLocation: '会場 Tokyo Dome',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(setlist.name, contains('セットリスト'));
        expect(setlist.description, contains('🎵'));
        expect(setlist.eventLocation, contains('Tokyo'));
      });

      test('handles many songIds', () {
        final manySongIds = List.generate(100, (i) => 'song-$i');
        final setlist = Setlist(
          id: 'setlist-id-23',
          bandId: 'band-23',
          name: 'Big Setlist',
          songIds: manySongIds,
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(setlist.songIds.length, 100);
        expect(setlist.songIds.first, 'song-0');
        expect(setlist.songIds.last, 'song-99');
      });

      test('handles large totalDuration', () {
        final setlist = Setlist(
          id: 'setlist-id-24',
          bandId: 'band-24',
          name: 'Long Setlist',
          totalDuration: 86400, // 24 hours in seconds
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(setlist.totalDuration, 86400);
      });
    });

    group('Default Values', () {
      test('default songIds is empty list', () {
        final setlist = Setlist(
          id: 'setlist-id-25',
          bandId: 'band-25',
          name: 'Default Setlist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(setlist.songIds, equals([]));
      });

      test('fromJson default songIds is empty list when null', () {
        final json = {
          'id': 'setlist-id-26',
          'bandId': 'band-26',
          'name': 'Default Songs Setlist',
          'songIds': null,
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final setlist = Setlist.fromJson(json);

        expect(setlist.songIds, equals([]));
      });
    });
  });
}
