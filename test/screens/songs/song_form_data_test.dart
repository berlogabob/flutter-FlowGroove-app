import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/screens/songs/models/song_form_data.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/link.dart';
import 'package:flutter_repsync_app/models/beat_mode.dart';

void main() {
  group('SongFormData - Metronome Settings', () {
    group('Constructor', () {
      test('creates SongFormData with default metronome settings', () {
        final formData = SongFormData(
          title: 'Test Song',
          artist: 'Test Artist',
        );

        expect(formData.accentBeats, 4);
        expect(formData.regularBeats, 1);
        expect(formData.beatModes, isEmpty);
      });

      test('creates SongFormData with custom metronome settings', () {
        final beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        final formData = SongFormData(
          title: 'Test Song',
          artist: 'Test Artist',
          accentBeats: 6,
          regularBeats: 2,
          beatModes: beatModes,
        );

        expect(formData.accentBeats, 6);
        expect(formData.regularBeats, 2);
        expect(formData.beatModes.length, 2);
        expect(formData.beatModes[0][0], BeatMode.accent);
        expect(formData.beatModes[1][1], BeatMode.accent);
      });
    });

    group('fromSong', () {
      test('creates SongFormData from Song with metronome settings', () {
        final beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
          [BeatMode.normal, BeatMode.silent],
          [BeatMode.normal, BeatMode.normal],
        ];

        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          originalKey: 'C',
          originalBPM: 120,
          ourKey: 'D',
          ourBPM: 125,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          accentBeats: 4,
          regularBeats: 2,
          beatModes: beatModes,
        );

        final formData = SongFormData.fromSong(song);

        expect(formData.title, 'Test Song');
        expect(formData.artist, 'Test Artist');
        expect(formData.originalBpm, '120');
        expect(formData.ourBpm, '125');
        expect(formData.accentBeats, 4);
        expect(formData.regularBeats, 2);
        expect(formData.beatModes.length, 4);
        expect(formData.beatModes[0][0], BeatMode.accent);
        expect(formData.beatModes[1][0], BeatMode.silent);
      });

      test(
        'creates SongFormData from Song with default metronome settings',
        () {
          final song = Song(
            id: 'song-2',
            title: 'Simple Song',
            artist: 'Simple Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          );

          final formData = SongFormData.fromSong(song);

          expect(formData.accentBeats, 4);
          expect(formData.regularBeats, 1);
          expect(formData.beatModes, isEmpty);
        },
      );

      test('creates SongFormData from old Song without metronome settings', () {
        final song = Song(
          id: 'old-song',
          title: 'Old Song',
          artist: 'Old Artist',
          originalBPM: 100,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final formData = SongFormData.fromSong(song);

        expect(formData.accentBeats, 4); // Default
        expect(formData.regularBeats, 1); // Default
        expect(formData.beatModes, isEmpty); // Default
        expect(formData.originalBpm, '100');
      });
    });

    group('toSong', () {
      test('creates Song with metronome settings', () {
        final beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        final formData = SongFormData(
          title: 'Test Song',
          artist: 'Test Artist',
          originalBpm: '120',
          ourBpm: '125',
          accentBeats: 4,
          regularBeats: 2,
          beatModes: beatModes,
        );

        final song = formData.toSong(
          id: 'song-1',
          createdAt: DateTime(2024, 1, 1),
        );

        expect(song.title, 'Test Song');
        expect(song.artist, 'Test Artist');
        expect(song.originalBPM, 120);
        expect(song.ourBPM, 125);
        expect(song.accentBeats, 4);
        expect(song.regularBeats, 2);
        expect(song.beatModes.length, 2);
        expect(song.beatModes[0][0], BeatMode.accent);
        expect(song.beatModes[1][1], BeatMode.accent);
      });

      test('creates Song with default metronome settings', () {
        final formData = SongFormData(
          title: 'Test Song',
          artist: 'Test Artist',
        );

        final song = formData.toSong(
          id: 'song-2',
          createdAt: DateTime(2024, 1, 1),
        );

        expect(song.accentBeats, 4);
        expect(song.regularBeats, 1);
        expect(song.beatModes, isEmpty);
      });

      test('creates Song with band sharing fields and metronome settings', () {
        final formData = SongFormData(
          title: 'Band Song',
          artist: 'Band Artist',
          accentBeats: 6,
          regularBeats: 2,
        );

        final song = formData.toSong(
          id: 'song-3',
          createdAt: DateTime(2024, 1, 1),
          bandId: 'band-123',
          originalOwnerId: 'user-1',
          contributedBy: 'Contributor',
          isCopy: true,
          contributedAt: DateTime(2024, 1, 2),
        );

        expect(song.bandId, 'band-123');
        expect(song.originalOwnerId, 'user-1');
        expect(song.contributedBy, 'Contributor');
        expect(song.isCopy, isTrue);
        expect(song.accentBeats, 6);
        expect(song.regularBeats, 2);
      });
    });

    group('updateAccentBeats', () {
      test('updates accentBeats value', () {
        final formData = SongFormData();
        formData.updateAccentBeats(6);
        expect(formData.accentBeats, 6);
      });

      test('can update to minimum value', () {
        final formData = SongFormData();
        formData.updateAccentBeats(1);
        expect(formData.accentBeats, 1);
      });

      test('can update to maximum value', () {
        final formData = SongFormData();
        formData.updateAccentBeats(16);
        expect(formData.accentBeats, 16);
      });
    });

    group('updateRegularBeats', () {
      test('updates regularBeats value', () {
        final formData = SongFormData();
        formData.updateRegularBeats(4);
        expect(formData.regularBeats, 4);
      });

      test('can update to minimum value', () {
        final formData = SongFormData();
        formData.updateRegularBeats(1);
        expect(formData.regularBeats, 1);
      });

      test('can update to maximum value', () {
        final formData = SongFormData();
        formData.updateRegularBeats(8);
        expect(formData.regularBeats, 8);
      });
    });

    group('updateBeatMode', () {
      test('updates beat mode at specified position', () {
        final formData = SongFormData();
        formData.updateBeatMode(0, 0, BeatMode.accent);

        expect(formData.beatModes.length, 1);
        expect(formData.beatModes[0][0], BeatMode.accent);
      });

      test('expands beatModes grid when needed', () {
        final formData = SongFormData();
        formData.updateBeatMode(3, 2, BeatMode.silent);

        expect(formData.beatModes.length, 4);
        expect(formData.beatModes[3].length, 3);
        expect(formData.beatModes[3][2], BeatMode.silent);
      });

      test('updates multiple beat modes', () {
        final formData = SongFormData();
        formData.updateBeatMode(0, 0, BeatMode.accent);
        formData.updateBeatMode(0, 1, BeatMode.normal);
        formData.updateBeatMode(1, 0, BeatMode.silent);

        expect(formData.beatModes.length, 2);
        expect(formData.beatModes[0][0], BeatMode.accent);
        expect(formData.beatModes[0][1], BeatMode.normal);
        expect(formData.beatModes[1][0], BeatMode.silent);
      });

      test('can change existing beat mode', () {
        final formData = SongFormData();
        formData.updateBeatMode(0, 0, BeatMode.accent);
        formData.updateBeatMode(0, 0, BeatMode.silent);

        expect(formData.beatModes[0][0], BeatMode.silent);
      });
    });

    group('initializeBeatModes', () {
      test(
        'initializes beatModes grid based on accentBeats and regularBeats',
        () {
          final formData = SongFormData(accentBeats: 4, regularBeats: 2);
          formData.initializeBeatModes();

          expect(formData.beatModes.length, 4);
          expect(formData.beatModes[0].length, 2);
          // First beat (all subdivisions) is accent by default
          expect(formData.beatModes[0][0], BeatMode.accent);
          expect(formData.beatModes[0][1], BeatMode.accent);
          // Other beats are normal
          expect(formData.beatModes[1][0], BeatMode.normal);
          expect(formData.beatModes[3][1], BeatMode.normal);
        },
      );

      test('initializes with single subdivision', () {
        final formData = SongFormData(accentBeats: 3, regularBeats: 1);
        formData.initializeBeatModes();

        expect(formData.beatModes.length, 3);
        expect(formData.beatModes[0].length, 1);
        expect(formData.beatModes[0][0], BeatMode.accent);
        expect(formData.beatModes[1][0], BeatMode.normal);
        expect(formData.beatModes[2][0], BeatMode.normal);
      });

      test('clears existing beatModes before initializing', () {
        final formData = SongFormData(accentBeats: 4, regularBeats: 2);
        formData.updateBeatMode(0, 0, BeatMode.silent);
        formData.initializeBeatModes();

        expect(formData.beatModes.length, 4);
        // Grid is reinitialized with correct dimensions
        expect(formData.beatModes.length, greaterThan(0));
      });
    });

    group('clear', () {
      test('clears metronome settings to defaults', () {
        final formData = SongFormData(accentBeats: 6, regularBeats: 4);
        formData.updateBeatMode(0, 0, BeatMode.accent);

        formData.clear();

        expect(formData.accentBeats, 4);
        expect(formData.regularBeats, 1);
        expect(formData.beatModes, isEmpty);
      });
    });

    group('Integration with other form fields', () {
      test('metronome settings work with all other form fields', () {
        final formData = SongFormData(
          title: 'Complete Song',
          artist: 'Complete Artist',
          originalBpm: '120',
          ourBpm: '125',
          notes: 'Test notes',
          originalKeyBase: 'C',
          originalKeyModifier: '',
          ourKeyBase: 'D',
          ourKeyModifier: 'm',
          spotifyUrl: 'https://spotify.com/track',
          accentBeats: 4,
          regularBeats: 2,
        );
        formData.addLink(
          Link(type: Link.typeYoutubeOriginal, url: 'https://youtube.com'),
        );
        formData.toggleTag('rock', true);
        formData.updateBeatMode(0, 0, BeatMode.accent);

        expect(formData.title, 'Complete Song');
        expect(formData.artist, 'Complete Artist');
        expect(formData.originalBpm, '120');
        expect(formData.ourBpm, '125');
        expect(formData.notes, 'Test notes');
        expect(formData.originalKey, 'C');
        expect(formData.ourKey, 'dm');
        expect(formData.spotifyUrl, 'https://spotify.com/track');
        expect(formData.links.length, 1);
        expect(formData.selectedTags, ['rock']);
        expect(formData.accentBeats, 4);
        expect(formData.regularBeats, 2);
        expect(formData.beatModes[0][0], BeatMode.accent);
      });

      test('toSong preserves all fields including metronome settings', () {
        final formData = SongFormData(
          title: 'Full Song',
          artist: 'Full Artist',
          originalBpm: '100',
          ourBpm: '110',
          notes: 'Notes',
          accentBeats: 5,
          regularBeats: 3,
        );
        formData.updateBeatMode(0, 0, BeatMode.accent);

        final song = formData.toSong(
          id: 'song-1',
          createdAt: DateTime(2024, 1, 1),
        );

        expect(song.title, 'Full Song');
        expect(song.artist, 'Full Artist');
        expect(song.originalBPM, 100);
        expect(song.ourBPM, 110);
        expect(song.notes, 'Notes');
        expect(song.accentBeats, 5);
        expect(song.regularBeats, 3);
        expect(song.beatModes[0][0], BeatMode.accent);
      });
    });

    group('Edge cases', () {
      test('handles empty beatModes after clear', () {
        final formData = SongFormData();
        formData.updateBeatMode(0, 0, BeatMode.accent);
        formData.clear();
        expect(formData.beatModes, isEmpty);
      });

      test('handles updating beatModes beyond current size', () {
        final formData = SongFormData();
        formData.updateBeatMode(10, 5, BeatMode.accent);
        expect(formData.beatModes.length, 11);
        expect(formData.beatModes[10].length, 6);
        expect(formData.beatModes[10][5], BeatMode.accent);
      });
    });
  });
}
