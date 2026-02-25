import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/beat_mode.dart';

void main() {
  group('Song Model - Firestore Metronome Settings', () {
    final testDate = DateTime(2024, 1, 1);

    group('Song serialization with metronome settings', () {
      test('Song toJson includes metronome settings', () {
        final List<List<BeatMode>> beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 4,
          regularBeats: 2,
          beatModes: beatModes,
        );

        final json = song.toJson();

        expect(json['accentBeats'], 4);
        expect(json['regularBeats'], 2);
        expect(json['beatModes'], isA<List>());
        expect(json['beatModes'].length, 2);
        expect(json['beatModes'][0][0], 'accent');
        expect(json['beatModes'][1][0], 'silent');
      });

      test('Song fromJson parses metronome settings', () {
        final json = {
          'id': 'song-1',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
          'accentBeats': 6,
          'regularBeats': 2,
          'beatModes': [
            ['accent', 'normal'],
            ['silent', 'accent'],
            ['normal', 'silent'],
            ['normal', 'normal'],
            ['normal', 'normal'],
            ['normal', 'normal'],
          ],
        };

        final song = Song.fromJson(json);

        expect(song.accentBeats, 6);
        expect(song.regularBeats, 2);
        expect(song.beatModes.length, 6);
        expect(song.beatModes[0][0], BeatMode.accent);
        expect(song.beatModes[1][0], BeatMode.silent);
      });

      test('Song with metronome settings round-trips correctly', () {
        final List<List<BeatMode>> originalBeatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
          [BeatMode.normal, BeatMode.silent],
          [BeatMode.normal, BeatMode.normal],
        ];

        final originalSong = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 4,
          regularBeats: 2,
          beatModes: originalBeatModes,
        );

        final json = originalSong.toJson();
        final restoredSong = Song.fromJson(json);

        expect(restoredSong.id, originalSong.id);
        expect(restoredSong.title, originalSong.title);
        expect(restoredSong.accentBeats, originalSong.accentBeats);
        expect(restoredSong.regularBeats, originalSong.regularBeats);
        expect(restoredSong.beatModes.length, originalSong.beatModes.length);
        expect(restoredSong.beatModes[0][0], BeatMode.accent);
        expect(restoredSong.beatModes[1][1], BeatMode.accent);
        expect(restoredSong.beatModes[2][1], BeatMode.silent);
      });
    });

    group('Old songs backward compatibility', () {
      test('Old songs without metronome fields load with defaults', () {
        final oldSongJson = {
          'id': 'old-song-1',
          'title': 'Old Song',
          'artist': 'Old Artist',
          'originalKey': 'C',
          'originalBPM': 120,
          'ourKey': 'D',
          'ourBPM': 130,
          'links': [],
          'tags': ['rock'],
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
        };

        final song = Song.fromJson(oldSongJson);

        expect(song.title, 'Old Song');
        expect(song.originalBPM, 120);
        expect(song.accentBeats, 4); // Default
        expect(song.regularBeats, 1); // Default
        expect(song.beatModes, isEmpty); // Default
      });

      test('Old songs saved again include metronome defaults', () {
        final oldSongJson = {
          'id': 'old-song-2',
          'title': 'Old Song',
          'artist': 'Old Artist',
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
        };

        final song = Song.fromJson(oldSongJson);
        final newJson = song.toJson();

        expect(newJson['accentBeats'], 4);
        expect(newJson['regularBeats'], 1);
        expect(newJson['beatModes'], isA<List>());
        expect(newJson['beatModes'].length, 0);
      });
    });

    group('Song copyWith for metronome settings', () {
      test('copyWith preserves metronome settings', () {
        final List<List<BeatMode>> originalBeatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        final originalSong = Song(
          id: 'song-1',
          title: 'Original',
          artist: 'Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 6,
          regularBeats: 2,
          beatModes: originalBeatModes,
        );

        final copiedSong = originalSong.copyWith(title: 'Updated');

        expect(copiedSong.title, 'Updated');
        expect(copiedSong.accentBeats, 6);
        expect(copiedSong.regularBeats, 2);
        expect(copiedSong.beatModes.length, 2);
        expect(copiedSong.beatModes[0][0], BeatMode.accent);
      });

      test('copyWith can update metronome settings', () {
        final originalSong = Song(
          id: 'song-1',
          title: 'Original',
          artist: 'Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 4,
          regularBeats: 1,
          beatModes: [],
        );

        final List<List<BeatMode>> newBeatModes = [
          [BeatMode.accent],
        ];
        final copiedSong = originalSong.copyWith(
          accentBeats: 3,
          regularBeats: 2,
          beatModes: newBeatModes,
        );

        expect(copiedSong.accentBeats, 3);
        expect(copiedSong.regularBeats, 2);
        expect(copiedSong.beatModes.length, 1);
        expect(copiedSong.beatModes[0][0], BeatMode.accent);
      });

      test('copyWith for band sharing preserves metronome settings', () {
        final originalSong = Song(
          id: 'song-1',
          title: 'Original',
          artist: 'Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 5,
          regularBeats: 2,
          beatModes: [
            [BeatMode.accent, BeatMode.normal],
          ],
        );

        final copiedSong = originalSong.copyWith(
          id: 'song-2',
          bandId: 'band-123',
          originalOwnerId: 'user-1',
          contributedBy: 'Contributor',
          isCopy: true,
          contributedAt: DateTime(2024, 1, 2),
        );

        expect(copiedSong.bandId, 'band-123');
        expect(copiedSong.originalOwnerId, 'user-1');
        expect(copiedSong.isCopy, isTrue);
        expect(copiedSong.accentBeats, 5);
        expect(copiedSong.regularBeats, 2);
        expect(copiedSong.beatModes[0][0], BeatMode.accent);
      });
    });

    group('Metronome settings in song queries', () {
      test('Songs with metronome settings can be filtered', () {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Song 1',
            artist: 'Artist',
            createdAt: testDate,
            updatedAt: testDate,
            accentBeats: 4,
            regularBeats: 1,
          ),
          Song(
            id: 'song-2',
            title: 'Song 2',
            artist: 'Artist',
            createdAt: testDate,
            updatedAt: testDate,
            accentBeats: 6,
            regularBeats: 2,
          ),
          Song(
            id: 'song-3',
            title: 'Song 3',
            artist: 'Artist',
            createdAt: testDate,
            updatedAt: testDate,
            accentBeats: 3,
            regularBeats: 1,
          ),
        ];

        final songsWithSixBeats = songs
            .where((s) => s.accentBeats == 6)
            .toList();
        expect(songsWithSixBeats.length, 1);
        expect(songsWithSixBeats[0].id, 'song-2');
      });

      test('Songs with custom beatModes can be filtered', () {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Song 1',
            artist: 'Artist',
            createdAt: testDate,
            updatedAt: testDate,
            beatModes: [],
          ),
          Song(
            id: 'song-2',
            title: 'Song 2',
            artist: 'Artist',
            createdAt: testDate,
            updatedAt: testDate,
            beatModes: [
              [BeatMode.accent, BeatMode.normal],
            ],
          ),
        ];

        final songsWithCustomModes = songs
            .where((s) => s.beatModes.isNotEmpty)
            .toList();
        expect(songsWithCustomModes.length, 1);
        expect(songsWithCustomModes[0].id, 'song-2');
      });
    });

    group('Error handling for metronome settings', () {
      test('Song with invalid beatModes falls back to defaults', () {
        final json = {
          'id': 'song-1',
          'title': 'Test',
          'artist': 'Artist',
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
          'beatModes': [
            ['invalid_mode', 'another_invalid'],
          ],
        };

        final song = Song.fromJson(json);

        expect(song.beatModes.length, 1);
        expect(song.beatModes[0][0], BeatMode.normal); // Falls back
        expect(song.beatModes[0][1], BeatMode.normal); // Falls back
      });

      test('Song with null beatModes uses empty list', () {
        final json = {
          'id': 'song-1',
          'title': 'Test',
          'artist': 'Artist',
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
          'beatModes': null,
        };

        final song = Song.fromJson(json);
        expect(song.beatModes, isEmpty);
      });
    });

    group('Metronome settings data integrity', () {
      test(
        'Metronome settings survive multiple serialize/deserialize cycles',
        () {
          final List<List<BeatMode>> originalBeatModes = [
            [BeatMode.accent, BeatMode.normal, BeatMode.silent],
            [BeatMode.normal, BeatMode.accent, BeatMode.normal],
            [BeatMode.silent, BeatMode.normal, BeatMode.accent],
          ];

          Song currentSong = Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Test Artist',
            createdAt: testDate,
            updatedAt: testDate,
            accentBeats: 3,
            regularBeats: 3,
            beatModes: originalBeatModes,
          );

          // Cycle 3 times
          for (int i = 0; i < 3; i++) {
            final json = currentSong.toJson();
            currentSong = Song.fromJson(json);
          }

          expect(currentSong.accentBeats, 3);
          expect(currentSong.regularBeats, 3);
          expect(currentSong.beatModes.length, 3);
          expect(currentSong.beatModes[0][0], BeatMode.accent);
          expect(currentSong.beatModes[1][1], BeatMode.accent);
          expect(currentSong.beatModes[2][2], BeatMode.accent);
          expect(currentSong.beatModes[0][2], BeatMode.silent);
        },
      );

      test('Empty beatModes remains empty after serialization', () {
        final song = Song(
          id: 'song-1',
          title: 'Test',
          artist: 'Artist',
          createdAt: testDate,
          updatedAt: testDate,
          beatModes: [],
        );

        final json = song.toJson();
        final restored = Song.fromJson(json);

        expect(restored.beatModes, isEmpty);
      });
    });

    group('Firestore paths documentation', () {
      test('Personal songs path structure documented', () {
        // Path: users/{uid}/songs/{songId}
        // Metronome settings are part of song document
        expect(true, isTrue);
      });

      test('Band songs path structure documented', () {
        // Path: bands/{bandId}/songs/{songId}
        // Metronome settings are part of song document
        expect(true, isTrue);
      });
    });
  });
}
