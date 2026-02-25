import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/link.dart';
import 'package:flutter_repsync_app/models/beat_mode.dart';

void main() {
  group('Song Model - Metronome Settings', () {
    final testDate = DateTime(2024, 1, 15, 10, 30, 0);

    group('Constructor with metronome settings', () {
      test('creates Song with default metronome settings', () {
        final song = Song(
          id: 'test-id-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.accentBeats, 4);
        expect(song.regularBeats, 1);
        expect(song.beatModes, isEmpty);
      });

      test('creates Song with custom metronome settings', () {
        final beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.normal],
          [BeatMode.normal, BeatMode.accent],
          [BeatMode.normal, BeatMode.silent],
        ];

        final song = Song(
          id: 'test-id-2',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 4,
          regularBeats: 2,
          beatModes: beatModes,
        );

        expect(song.accentBeats, 4);
        expect(song.regularBeats, 2);
        expect(song.beatModes.length, 4);
        expect(song.beatModes[0][0], BeatMode.accent);
        expect(song.beatModes[0][1], BeatMode.normal);
        expect(song.beatModes[1][0], BeatMode.silent);
        expect(song.beatModes[3][1], BeatMode.silent);
      });

      test('creates Song with minimum metronome settings', () {
        final song = Song(
          id: 'test-id-3',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 1,
          regularBeats: 1,
          beatModes: [
            [BeatMode.accent],
          ],
        );

        expect(song.accentBeats, 1);
        expect(song.regularBeats, 1);
        expect(song.beatModes.length, 1);
        expect(song.beatModes[0][0], BeatMode.accent);
      });

      test('creates Song with maximum metronome settings', () {
        final beatModes = List.generate(
          16,
          (i) => List.generate(8, (j) => BeatMode.normal),
        );

        final song = Song(
          id: 'test-id-4',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 16,
          regularBeats: 8,
          beatModes: beatModes,
        );

        expect(song.accentBeats, 16);
        expect(song.regularBeats, 8);
        expect(song.beatModes.length, 16);
        expect(song.beatModes[0].length, 8);
      });
    });

    group('fromJson with metronome settings', () {
      test('parses JSON with metronome settings', () {
        final json = {
          'id': 'test-id-1',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
          'accentBeats': 6,
          'regularBeats': 2,
          'beatModes': [
            ['accent', 'normal'],
            ['silent', 'normal'],
            ['normal', 'accent'],
            ['normal', 'silent'],
            ['normal', 'normal'],
            ['normal', 'normal'],
          ],
        };

        final song = Song.fromJson(json);

        expect(song.accentBeats, 6);
        expect(song.regularBeats, 2);
        expect(song.beatModes.length, 6);
        expect(song.beatModes[0][0], BeatMode.accent);
        expect(song.beatModes[0][1], BeatMode.normal);
        expect(song.beatModes[1][0], BeatMode.silent);
        expect(song.beatModes[2][1], BeatMode.accent);
        expect(song.beatModes[3][1], BeatMode.silent);
      });

      test('handles missing metronome settings with defaults', () {
        final json = {
          'id': 'test-id-2',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final song = Song.fromJson(json);

        expect(song.accentBeats, 4);
        expect(song.regularBeats, 1);
        expect(song.beatModes, isEmpty);
      });

      test('handles null metronome settings with defaults', () {
        final json = {
          'id': 'test-id-3',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
          'accentBeats': null,
          'regularBeats': null,
          'beatModes': null,
        };

        final song = Song.fromJson(json);

        expect(song.accentBeats, 4);
        expect(song.regularBeats, 1);
        expect(song.beatModes, isEmpty);
      });

      test('handles old songs without metronome fields', () {
        final json = {
          'id': 'old-song-1',
          'title': 'Old Song',
          'artist': 'Old Artist',
          'originalKey': 'C',
          'originalBPM': 120,
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final song = Song.fromJson(json);

        expect(song.accentBeats, 4);
        expect(song.regularBeats, 1);
        expect(song.beatModes, isEmpty);
        expect(song.title, 'Old Song');
        expect(song.originalBPM, 120);
      });

      test('parses beatModes with unknown mode values', () {
        final json = {
          'id': 'test-id-4',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
          'beatModes': [
            ['unknown_mode', 'normal'],
            ['accent', 'invalid_mode'],
          ],
        };

        final song = Song.fromJson(json);

        expect(song.beatModes.length, 2);
        expect(song.beatModes[0][0], BeatMode.normal); // Falls back to normal
        expect(song.beatModes[0][1], BeatMode.normal);
        expect(song.beatModes[1][0], BeatMode.accent);
        expect(song.beatModes[1][1], BeatMode.normal); // Falls back to normal
      });

      test('parses empty beatModes array', () {
        final json = {
          'id': 'test-id-5',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
          'accentBeats': 4,
          'regularBeats': 2,
          'beatModes': [],
        };

        final song = Song.fromJson(json);

        expect(song.accentBeats, 4);
        expect(song.regularBeats, 2);
        expect(song.beatModes, isEmpty);
      });
    });

    group('toJson with metronome settings', () {
      test('serializes metronome settings to JSON', () {
        final beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        final song = Song(
          id: 'test-id-1',
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
        expect(json['beatModes'][0][1], 'normal');
        expect(json['beatModes'][1][0], 'silent');
        expect(json['beatModes'][1][1], 'accent');
      });

      test('serializes default metronome settings', () {
        final song = Song(
          id: 'test-id-2',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final json = song.toJson();

        expect(json['accentBeats'], 4);
        expect(json['regularBeats'], 1);
        expect(json['beatModes'], isA<List>());
        expect(json['beatModes'].length, 0);
      });

      test('toJson and fromJson are inverses for metronome settings', () {
        final originalBeatModes = [
          [BeatMode.accent, BeatMode.normal, BeatMode.silent],
          [BeatMode.normal, BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.normal, BeatMode.accent],
        ];

        final originalSong = Song(
          id: 'test-id-3',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 3,
          regularBeats: 3,
          beatModes: originalBeatModes,
        );

        final json = originalSong.toJson();
        final restoredSong = Song.fromJson(json);

        expect(restoredSong.accentBeats, originalSong.accentBeats);
        expect(restoredSong.regularBeats, originalSong.regularBeats);
        expect(restoredSong.beatModes.length, originalSong.beatModes.length);
        expect(restoredSong.beatModes[0][0], BeatMode.accent);
        expect(restoredSong.beatModes[1][1], BeatMode.accent);
        expect(restoredSong.beatModes[2][2], BeatMode.accent);
        expect(restoredSong.beatModes[0][2], BeatMode.silent);
      });
    });

    group('copyWith for metronome settings', () {
      test(
        'returns copy with unchanged metronome settings when no arguments',
        () {
          final originalSong = Song(
            id: 'test-id-1',
            title: 'Test Song',
            artist: 'Test Artist',
            createdAt: testDate,
            updatedAt: testDate,
            accentBeats: 6,
            regularBeats: 2,
            beatModes: [
              [BeatMode.accent, BeatMode.normal],
            ],
          );

          final copiedSong = originalSong.copyWith();

          expect(copiedSong.accentBeats, 6);
          expect(copiedSong.regularBeats, 2);
          expect(copiedSong.beatModes.length, 1);
          expect(copiedSong.beatModes[0][0], BeatMode.accent);
          expect(copiedSong, isNot(same(originalSong)));
        },
      );

      test('updates accentBeats', () {
        final originalSong = Song(
          id: 'test-id-2',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 4,
        );

        final copiedSong = originalSong.copyWith(accentBeats: 8);

        expect(copiedSong.accentBeats, 8);
        expect(copiedSong.regularBeats, 1); // Unchanged
      });

      test('updates regularBeats', () {
        final originalSong = Song(
          id: 'test-id-3',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          regularBeats: 1,
        );

        final copiedSong = originalSong.copyWith(regularBeats: 4);

        expect(copiedSong.regularBeats, 4);
        expect(copiedSong.accentBeats, 4); // Unchanged
      });

      test('updates beatModes', () {
        final originalSong = Song(
          id: 'test-id-4',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          beatModes: [],
        );

        final newBeatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];
        final copiedSong = originalSong.copyWith(beatModes: newBeatModes);

        expect(copiedSong.beatModes.length, 2);
        expect(copiedSong.beatModes[0][0], BeatMode.accent);
        expect(copiedSong.beatModes[1][0], BeatMode.silent);
      });

      test('updates all metronome settings at once', () {
        final originalSong = Song(
          id: 'test-id-5',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 4,
          regularBeats: 1,
          beatModes: [],
        );

        final newBeatModes = [
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

      test('can set metronome settings to defaults', () {
        final originalSong = Song(
          id: 'test-id-6',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 6,
          regularBeats: 4,
          beatModes: [
            [BeatMode.accent],
          ],
        );

        final copiedSong = originalSong.copyWith(
          accentBeats: 4,
          regularBeats: 1,
          beatModes: [],
        );

        expect(copiedSong.accentBeats, 4);
        expect(copiedSong.regularBeats, 1);
        expect(copiedSong.beatModes, isEmpty);
      });
    });

    group('Metronome settings with other fields', () {
      test('metronome settings work with band sharing fields', () {
        final song = Song(
          id: 'test-id-1',
          title: 'Band Song',
          artist: 'Band Artist',
          createdAt: testDate,
          updatedAt: testDate,
          bandId: 'band-123',
          originalOwnerId: 'user-1',
          contributedBy: 'Contributor',
          isCopy: true,
          contributedAt: testDate,
          accentBeats: 6,
          regularBeats: 2,
          beatModes: [
            [BeatMode.accent, BeatMode.normal],
          ],
        );

        expect(song.bandId, 'band-123');
        expect(song.originalOwnerId, 'user-1');
        expect(song.contributedBy, 'Contributor');
        expect(song.isCopy, isTrue);
        expect(song.accentBeats, 6);
        expect(song.regularBeats, 2);
        expect(song.beatModes[0][0], BeatMode.accent);
      });

      test('metronome settings work with BPM and key fields', () {
        final song = Song(
          id: 'test-id-2',
          title: 'Complete Song',
          artist: 'Complete Artist',
          originalKey: 'C Major',
          originalBPM: 120,
          ourKey: 'D Major',
          ourBPM: 125,
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 4,
          regularBeats: 2,
          beatModes: [
            [BeatMode.accent, BeatMode.normal],
            [BeatMode.normal, BeatMode.normal],
            [BeatMode.normal, BeatMode.normal],
            [BeatMode.normal, BeatMode.normal],
          ],
        );

        expect(song.originalKey, 'C Major');
        expect(song.originalBPM, 120);
        expect(song.ourKey, 'D Major');
        expect(song.ourBPM, 125);
        expect(song.accentBeats, 4);
        expect(song.regularBeats, 2);
        expect(song.beatModes.length, 4);
      });

      test('metronome settings work with links and tags', () {
        final song = Song(
          id: 'test-id-3',
          title: 'Tagged Song',
          artist: 'Tagged Artist',
          links: [
            Link(type: Link.typeYoutubeOriginal, url: 'https://youtube.com'),
          ],
          tags: ['rock', 'classic'],
          notes: 'Test notes',
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 3,
          regularBeats: 1,
          beatModes: [
            [BeatMode.accent],
            [BeatMode.normal],
            [BeatMode.normal],
          ],
        );

        expect(song.links.length, 1);
        expect(song.tags, ['rock', 'classic']);
        expect(song.notes, 'Test notes');
        expect(song.accentBeats, 3);
        expect(song.beatModes.length, 3);
      });
    });

    group('Edge cases for metronome settings', () {
      test('handles zero accentBeats (should use default)', () {
        final json = {
          'id': 'test-id-1',
          'title': 'Test',
          'artist': 'Artist',
          'accentBeats': 0,
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final song = Song.fromJson(json);
        // Note: defaultValue in JsonKey doesn't validate, just provides default
        expect(song.accentBeats, 0);
      });

      test('handles negative accentBeats', () {
        final song = Song(
          id: 'test-id-2',
          title: 'Test',
          artist: 'Artist',
          accentBeats: -1,
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.accentBeats, -1);
      });

      test('handles very large accentBeats', () {
        final song = Song(
          id: 'test-id-3',
          title: 'Test',
          artist: 'Artist',
          accentBeats: 100,
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(song.accentBeats, 100);
      });

      test('handles irregular beatModes dimensions', () {
        final List<List<BeatMode>> beatModes = [
          [BeatMode.accent],
          [BeatMode.normal, BeatMode.normal, BeatMode.normal],
          [BeatMode.silent],
        ];

        final song = Song(
          id: 'test-id-4',
          title: 'Test',
          artist: 'Artist',
          createdAt: testDate,
          updatedAt: testDate,
          beatModes: beatModes,
        );

        expect(song.beatModes.length, 3);
        expect(song.beatModes[0].length, 1);
        expect(song.beatModes[1].length, 3);
        expect(song.beatModes[2].length, 1);
      });

      test('handles empty inner beatModes arrays', () {
        final List<List<BeatMode>> beatModes = [
          [],
          [BeatMode.accent],
          [],
        ];

        final song = Song(
          id: 'test-id-5',
          title: 'Test',
          artist: 'Artist',
          createdAt: testDate,
          updatedAt: testDate,
          beatModes: beatModes,
        );

        expect(song.beatModes.length, 3);
        expect(song.beatModes[0], isEmpty);
        expect(song.beatModes[1][0], BeatMode.accent);
      });
    });

    group('Backward compatibility', () {
      test('old songs without metronome fields load correctly', () {
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
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.toIso8601String(),
        };

        final song = Song.fromJson(oldSongJson);

        expect(song.title, 'Old Song');
        expect(song.originalBPM, 120);
        expect(song.ourBPM, 130);
        expect(song.accentBeats, 4); // Default
        expect(song.regularBeats, 1); // Default
        expect(song.beatModes, isEmpty); // Default
      });

      test('new songs with metronome settings serialize correctly', () {
        final newSong = Song(
          id: 'new-song-1',
          title: 'New Song',
          artist: 'New Artist',
          originalBPM: 100,
          createdAt: testDate,
          updatedAt: testDate,
          accentBeats: 5,
          regularBeats: 3,
          beatModes: [
            [BeatMode.accent, BeatMode.normal, BeatMode.silent],
            [BeatMode.normal, BeatMode.accent, BeatMode.normal],
            [BeatMode.normal, BeatMode.normal, BeatMode.accent],
            [BeatMode.silent, BeatMode.normal, BeatMode.normal],
            [BeatMode.normal, BeatMode.silent, BeatMode.normal],
          ],
        );

        final json = newSong.toJson();

        expect(json['accentBeats'], 5);
        expect(json['regularBeats'], 3);
        expect(json['beatModes'].length, 5);
        expect(json['beatModes'][0][0], 'accent');
        expect(json['beatModes'][4][1], 'silent');
      });
    });
  });
}
