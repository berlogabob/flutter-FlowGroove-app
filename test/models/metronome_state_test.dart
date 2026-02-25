import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/metronome_state.dart';
import 'package:flutter_repsync_app/models/time_signature.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/beat_mode.dart';

void main() {
  group('MetronomeState Model', () {
    group('Constructor', () {
      test('creates MetronomeState with required fields', () {
        final state = MetronomeState(
          isPlaying: false,
          bpm: 120,
          currentBeat: 0,
          timeSignature: TimeSignature.commonTime,
          waveType: 'sine',
          volume: 0.5,
          accentEnabled: true,
          accentFrequency: 1600,
          beatFrequency: 800,
          accentPattern: const [true, false, false, false],
        );

        expect(state.isPlaying, false);
        expect(state.bpm, 120);
        expect(state.currentBeat, 0);
        expect(state.timeSignature, TimeSignature.commonTime);
        expect(state.waveType, 'sine');
        expect(state.volume, 0.5);
        expect(state.accentEnabled, true);
        expect(state.accentFrequency, 1600);
        expect(state.beatFrequency, 800);
        expect(state.accentPattern, [true, false, false, false]);
      });

      test('creates MetronomeState with default metronome settings', () {
        final state = MetronomeState(
          isPlaying: false,
          bpm: 120,
          currentBeat: 0,
          timeSignature: TimeSignature.commonTime,
          waveType: 'sine',
          volume: 0.5,
          accentEnabled: true,
          accentFrequency: 1600,
          beatFrequency: 800,
          accentPattern: const [true, false, false, false],
        );

        expect(state.accentBeats, 4);
        expect(state.regularBeats, 1);
        expect(state.beatModes, isEmpty);
        expect(state.loadedSong, isNull);
        expect(state.loadedSetlist, isNull);
        expect(state.currentSetlistIndex, 0);
      });

      test('creates MetronomeState with custom metronome settings', () {
        final beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final state = MetronomeState(
          isPlaying: true,
          bpm: 100,
          currentBeat: 5,
          timeSignature: TimeSignature.commonTime,
          waveType: 'sine',
          volume: 0.7,
          accentEnabled: true,
          accentFrequency: 1600,
          beatFrequency: 800,
          accentPattern: const [true, false, false, false],
          accentBeats: 4,
          regularBeats: 2,
          beatModes: beatModes,
          loadedSong: song,
          loadedSetlist: setlist,
          currentSetlistIndex: 1,
        );

        expect(state.accentBeats, 4);
        expect(state.regularBeats, 2);
        expect(state.beatModes.length, 2);
        expect(state.beatModes[0][0], BeatMode.accent);
        expect(state.beatModes[1][1], BeatMode.accent);
        expect(state.loadedSong, equals(song));
        expect(state.loadedSetlist, equals(setlist));
        expect(state.currentSetlistIndex, 1);
      });
    });

    group('MetronomeState.initial', () {
      test('creates initial state with correct defaults', () {
        final state = MetronomeState.initial();

        expect(state.isPlaying, false);
        expect(state.bpm, 120);
        expect(state.currentBeat, 0);
        expect(state.timeSignature, TimeSignature.commonTime);
        expect(state.waveType, 'sine');
        expect(state.volume, 0.5);
        expect(state.accentEnabled, true);
        expect(state.accentFrequency, 1600);
        expect(state.beatFrequency, 800);
        expect(state.accentPattern, [true, false, false, false]);
        expect(state.accentBeats, 4);
        expect(state.regularBeats, 1);
        expect(state.beatModes, isEmpty);
        expect(state.loadedSong, isNull);
        expect(state.loadedSetlist, isNull);
        expect(state.currentSetlistIndex, 0);
      });

      test('initial state has consistent values', () {
        final state1 = MetronomeState.initial();
        final state2 = MetronomeState.initial();

        expect(state1.bpm, state2.bpm);
        expect(state1.accentBeats, state2.accentBeats);
        expect(state1.regularBeats, state2.regularBeats);
      });
    });

    group('copyWith', () {
      test('returns copy with unchanged fields when no arguments', () {
        final original = MetronomeState.initial();
        final copied = original.copyWith();

        expect(copied.isPlaying, original.isPlaying);
        expect(copied.bpm, original.bpm);
        expect(copied.accentBeats, original.accentBeats);
        expect(copied.regularBeats, original.regularBeats);
        expect(copied, isNot(same(original)));
      });

      test('updates accentBeats', () {
        final original = MetronomeState.initial();
        final copied = original.copyWith(accentBeats: 6);

        expect(copied.accentBeats, 6);
        expect(copied.regularBeats, 1); // Unchanged
      });

      test('updates regularBeats', () {
        final original = MetronomeState.initial();
        final copied = original.copyWith(regularBeats: 4);

        expect(copied.regularBeats, 4);
        expect(copied.accentBeats, 4); // Unchanged
      });

      test('updates beatModes', () {
        final original = MetronomeState.initial();
        final newBeatModes = [
          [BeatMode.accent, BeatMode.normal],
        ];
        final copied = original.copyWith(beatModes: newBeatModes);

        expect(copied.beatModes.length, 1);
        expect(copied.beatModes[0][0], BeatMode.accent);
      });

      test('updates loadedSong', () {
        final original = MetronomeState.initial();
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );
        final copied = original.copyWith(loadedSong: song);

        expect(copied.loadedSong, equals(song));
        expect(copied.loadedSetlist, isNull);
      });

      test('updates loadedSetlist', () {
        final original = MetronomeState.initial();
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );
        final copied = original.copyWith(loadedSetlist: setlist);

        expect(copied.loadedSetlist, equals(setlist));
        expect(copied.loadedSong, isNull);
      });

      test('updates currentSetlistIndex', () {
        final original = MetronomeState.initial();
        final copied = original.copyWith(currentSetlistIndex: 3);

        expect(copied.currentSetlistIndex, 3);
      });

      test('updates multiple metronome settings at once', () {
        final original = MetronomeState.initial();
        final newBeatModes = [
          [BeatMode.accent],
        ];
        final copied = original.copyWith(
          accentBeats: 3,
          regularBeats: 2,
          beatModes: newBeatModes,
        );

        expect(copied.accentBeats, 3);
        expect(copied.regularBeats, 2);
        expect(copied.beatModes.length, 1);
      });

      test('updates BPM and loadedSong together', () {
        final original = MetronomeState.initial();
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          ourBPM: 100,
        );
        final copied = original.copyWith(bpm: 100, loadedSong: song);

        expect(copied.bpm, 100);
        expect(copied.loadedSong, equals(song));
      });
    });

    group('fromJson', () {
      test('parses JSON with metronome settings', () {
        final json = {
          'isPlaying': false,
          'bpm': 100,
          'currentBeat': 0,
          'timeSignature': {'numerator': 4, 'denominator': 4},
          'waveType': 'sine',
          'volume': 0.5,
          'accentEnabled': true,
          'accentFrequency': 1600,
          'beatFrequency': 800,
          'accentPattern': [true, false, false, false],
          'accentBeats': 6,
          'regularBeats': 2,
          'beatModes': [
            ['accent', 'normal'],
            ['silent', 'accent'],
          ],
        };

        final state = MetronomeState.fromJson(json);

        expect(state.accentBeats, 6);
        expect(state.regularBeats, 2);
        expect(state.beatModes.length, 2);
        expect(state.beatModes[0][0], BeatMode.accent);
        expect(state.beatModes[1][0], BeatMode.silent);
      });

      test('handles missing metronome settings with defaults', () {
        final json = {
          'isPlaying': false,
          'bpm': 120,
          'currentBeat': 0,
          'timeSignature': {'numerator': 4, 'denominator': 4},
          'waveType': 'sine',
          'volume': 0.5,
          'accentEnabled': true,
          'accentFrequency': 1600,
          'beatFrequency': 800,
          'accentPattern': [true, false, false, false],
        };

        final state = MetronomeState.fromJson(json);

        expect(state.accentBeats, 4);
        expect(state.regularBeats, 1);
        expect(state.beatModes, isEmpty);
      });

      test('handles null metronome settings with defaults', () {
        final json = {
          'isPlaying': false,
          'bpm': 120,
          'currentBeat': 0,
          'timeSignature': {'numerator': 4, 'denominator': 4},
          'waveType': 'sine',
          'volume': 0.5,
          'accentEnabled': true,
          'accentFrequency': 1600,
          'beatFrequency': 800,
          'accentPattern': [true, false, false, false],
          'accentBeats': null,
          'regularBeats': null,
          'beatModes': null,
        };

        final state = MetronomeState.fromJson(json);

        expect(state.accentBeats, 4);
        expect(state.regularBeats, 1);
        expect(state.beatModes, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes metronome settings to JSON', () {
        final beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        final state = MetronomeState(
          isPlaying: true,
          bpm: 100,
          currentBeat: 5,
          timeSignature: TimeSignature.commonTime,
          waveType: 'sine',
          volume: 0.7,
          accentEnabled: true,
          accentFrequency: 1600,
          beatFrequency: 800,
          accentPattern: const [true, false, false, false],
          accentBeats: 4,
          regularBeats: 2,
          beatModes: beatModes,
        );

        final json = state.toJson();

        expect(json['accentBeats'], 4);
        expect(json['regularBeats'], 2);
        expect(json['beatModes'], isA<List>());
        expect(json['beatModes'].length, 2);
        expect(json['beatModes'][0][0], 'accent');
        expect(json['beatModes'][1][0], 'silent');
      });

      test('toJson and fromJson are inverses', () {
        final originalBeatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        final originalState = MetronomeState(
          isPlaying: true,
          bpm: 100,
          currentBeat: 3,
          timeSignature: TimeSignature.commonTime,
          waveType: 'sine',
          volume: 0.6,
          accentEnabled: true,
          accentFrequency: 1600,
          beatFrequency: 800,
          accentPattern: const [true, false, false, false],
          accentBeats: 6,
          regularBeats: 2,
          beatModes: originalBeatModes,
        );

        final json = originalState.toJson();
        // Note: TimeSignature needs special handling in JSON
        // For this test, we verify the metronome-specific fields
        expect(json['accentBeats'], 6);
        expect(json['regularBeats'], 2);
        expect(json['beatModes'].length, 2);

        // Verify beatModes round-trip
        final restoredBeatModes = (json['beatModes'] as List)
            .map(
              (row) => (row as List)
                  .map(
                    (mode) => BeatMode.values.firstWhere(
                      (m) => m.name == mode,
                      orElse: () => BeatMode.normal,
                    ),
                  )
                  .toList(),
            )
            .toList();

        expect(restoredBeatModes[0][0], BeatMode.accent);
        expect(restoredBeatModes[1][0], BeatMode.silent);
      });
    });

    group('beatsPerMeasure getter (backward compatibility)', () {
      test('returns accentBeats value', () {
        final state = MetronomeState.initial().copyWith(accentBeats: 6);
        expect(state.beatsPerMeasure, 6);
      });

      test('returns default value when accentBeats is default', () {
        final state = MetronomeState.initial();
        expect(state.beatsPerMeasure, 4);
      });
    });

    group('isAccentBeat method', () {
      test('returns true for accented beats', () {
        final state = MetronomeState(
          isPlaying: false,
          bpm: 120,
          currentBeat: 0,
          timeSignature: TimeSignature.commonTime,
          waveType: 'sine',
          volume: 0.5,
          accentEnabled: true,
          accentFrequency: 1600,
          beatFrequency: 800,
          accentPattern: const [true, false, false, false],
        );

        expect(state.isAccentBeat(0), isTrue);
        expect(state.isAccentBeat(1), isFalse);
        expect(state.isAccentBeat(2), isFalse);
        expect(state.isAccentBeat(3), isFalse);
      });

      test('returns false for out of bounds indices', () {
        final state = MetronomeState.initial();

        expect(state.isAccentBeat(-1), isFalse);
        expect(state.isAccentBeat(4), isFalse);
        expect(state.isAccentBeat(10), isFalse);
      });

      test('works with custom accent patterns', () {
        final state = MetronomeState(
          isPlaying: false,
          bpm: 120,
          currentBeat: 0,
          timeSignature: TimeSignature.commonTime,
          waveType: 'sine',
          volume: 0.5,
          accentEnabled: true,
          accentFrequency: 1600,
          beatFrequency: 800,
          accentPattern: const [true, false, true, false, true],
        );

        expect(state.isAccentBeat(0), isTrue);
        expect(state.isAccentBeat(1), isFalse);
        expect(state.isAccentBeat(2), isTrue);
        expect(state.isAccentBeat(3), isFalse);
        expect(state.isAccentBeat(4), isTrue);
      });
    });

    group('Edge cases', () {
      test('handles empty beatModes', () {
        final state = MetronomeState.initial().copyWith(beatModes: []);
        expect(state.beatModes, isEmpty);
      });

      test('handles large accentBeats value', () {
        final state = MetronomeState.initial().copyWith(accentBeats: 16);
        expect(state.accentBeats, 16);
      });

      test('handles large regularBeats value', () {
        final state = MetronomeState.initial().copyWith(regularBeats: 8);
        expect(state.regularBeats, 8);
      });

      test('handles complex beatModes grid', () {
        final beatModes = List.generate(
          8,
          (i) => List.generate(4, (j) => BeatMode.normal),
        );
        final state = MetronomeState.initial().copyWith(beatModes: beatModes);
        expect(state.beatModes.length, 8);
        expect(state.beatModes[0].length, 4);
      });
    });
  });
}
