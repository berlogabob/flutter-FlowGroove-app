import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/beat_mode.dart';
import 'package:flutter_repsync_app/models/metronome_state.dart';

void main() {
  group('MetronomeState - Integration Tests', () {
    group('loadSongTempo simulation', () {
      test('state updates with song BPM and metronome settings', () {
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 100,
          ourBPM: 120,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          accentBeats: 6,
          regularBeats: 2,
        );

        // Simulate loadSongTempo logic
        var state = MetronomeState.initial();
        state = state.copyWith(loadedSong: song);

        final songBpm = song.ourBPM ?? song.originalBPM;
        if (songBpm != null) {
          state = state.copyWith(bpm: songBpm.clamp(1, 300));
        }

        state = state.copyWith(
          accentBeats: song.accentBeats,
          regularBeats: song.regularBeats,
        );

        expect(state.bpm, 120);
        expect(state.loadedSong, equals(song));
        expect(state.accentBeats, 6);
        expect(state.regularBeats, 2);
      });

      test('state falls back to originalBPM when ourBPM is null', () {
        final song = Song(
          id: 'song-2',
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 100,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        var state = MetronomeState.initial();
        state = state.copyWith(loadedSong: song);

        final songBpm = song.ourBPM ?? song.originalBPM;
        if (songBpm != null) {
          state = state.copyWith(bpm: songBpm.clamp(1, 300));
        }

        expect(state.bpm, 100);
      });

      test('state clamps BPM to valid range', () {
        final song = Song(
          id: 'song-3',
          title: 'Test Song',
          artist: 'Test Artist',
          ourBPM: 500, // Too high
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        var state = MetronomeState.initial();
        state = state.copyWith(loadedSong: song);

        final songBpm = song.ourBPM ?? song.originalBPM;
        if (songBpm != null) {
          state = state.copyWith(bpm: songBpm.clamp(1, 300));
        }

        expect(state.bpm, 300); // Clamped
      });
    });

    group('saveMetronomeToSong simulation', () {
      test('creates updated song with metronome settings', () {
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          ourBPM: 100,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        var state = MetronomeState.initial().copyWith(
          loadedSong: song,
          bpm: 120,
          accentBeats: 6,
          regularBeats: 2,
          beatModes: [
            [BeatMode.accent, BeatMode.normal],
          ],
        );

        // Simulate saveMetronomeToSong logic
        final songToSave = state.loadedSong;
        Song? updatedSong;
        if (songToSave != null) {
          updatedSong = songToSave.copyWith(
            accentBeats: state.accentBeats,
            regularBeats: state.regularBeats,
            beatModes: state.beatModes,
            ourBPM: state.bpm,
            updatedAt: DateTime.now(),
          );
          state = state.copyWith(loadedSong: updatedSong);
        }

        expect(updatedSong, isNotNull);
        expect(updatedSong!.accentBeats, 6);
        expect(updatedSong.regularBeats, 2);
        expect(updatedSong.beatModes[0][0], BeatMode.accent);
        expect(updatedSong.ourBPM, 120);
      });

      test('returns null when no song is loaded', () {
        final state = MetronomeState.initial();

        final songToSave = state.loadedSong;
        Song? updatedSong;
        if (songToSave != null) {
          updatedSong = songToSave.copyWith(
            accentBeats: state.accentBeats,
            regularBeats: state.regularBeats,
            beatModes: state.beatModes,
            ourBPM: state.bpm,
            updatedAt: DateTime.now(),
          );
        }

        expect(updatedSong, isNull);
      });
    });

    group('loadSetlistQueue simulation', () {
      test('state updates with setlist', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        var state = MetronomeState.initial();
        state = state.copyWith(loadedSetlist: setlist, currentSetlistIndex: 0);

        expect(state.loadedSetlist, equals(setlist));
        expect(state.currentSetlistIndex, 0);
      });
    });

    group('Setlist navigation simulation', () {
      test('nextSetlistSong increments index', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        var state = MetronomeState.initial().copyWith(
          loadedSetlist: setlist,
          currentSetlistIndex: 0,
        );

        // Simulate nextSetlistSong
        if (state.loadedSetlist != null) {
          final newIndex = state.currentSetlistIndex + 1;
          if (newIndex < state.loadedSetlist!.songIds.length) {
            state = state.copyWith(currentSetlistIndex: newIndex);
          }
        }

        expect(state.currentSetlistIndex, 1);
      });

      test('nextSetlistSong does not exceed song count', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        var state = MetronomeState.initial().copyWith(
          loadedSetlist: setlist,
          currentSetlistIndex: 0,
        );

        // Go to last song
        for (int i = 0; i < 3; i++) {
          if (state.loadedSetlist != null) {
            final newIndex = state.currentSetlistIndex + 1;
            if (newIndex < state.loadedSetlist!.songIds.length) {
              state = state.copyWith(currentSetlistIndex: newIndex);
            }
          }
        }

        expect(state.currentSetlistIndex, 1); // Max is 1 (0-indexed)
      });

      test('previousSetlistSong decrements index', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        var state = MetronomeState.initial().copyWith(
          loadedSetlist: setlist,
          currentSetlistIndex: 2,
        );

        // Simulate previousSetlistSong
        if (state.loadedSetlist != null) {
          if (state.currentSetlistIndex > 0) {
            state = state.copyWith(
              currentSetlistIndex: state.currentSetlistIndex - 1,
            );
          }
        }

        expect(state.currentSetlistIndex, 1);
      });

      test('previousSetlistSong does not go below zero', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        var state = MetronomeState.initial().copyWith(
          loadedSetlist: setlist,
          currentSetlistIndex: 0,
        );

        // Try to go below zero
        if (state.loadedSetlist != null) {
          if (state.currentSetlistIndex > 0) {
            state = state.copyWith(
              currentSetlistIndex: state.currentSetlistIndex - 1,
            );
          }
        }

        expect(state.currentSetlistIndex, 0);
      });
    });

    group('clearLoadedContent simulation', () {
      test('creates new state with null loadedSong', () {
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        // Create state with loaded song
        final stateWithSong = MetronomeState.initial().copyWith(
          loadedSong: song,
        );
        expect(stateWithSong.loadedSong, isNotNull);

        // Create new state without loaded song (simulating clearLoadedContent)
        final clearedState = MetronomeState(
          isPlaying: stateWithSong.isPlaying,
          bpm: stateWithSong.bpm,
          currentBeat: stateWithSong.currentBeat,
          timeSignature: stateWithSong.timeSignature,
          waveType: stateWithSong.waveType,
          volume: stateWithSong.volume,
          accentEnabled: stateWithSong.accentEnabled,
          accentFrequency: stateWithSong.accentFrequency,
          beatFrequency: stateWithSong.beatFrequency,
          accentPattern: stateWithSong.accentPattern,
          accentBeats: stateWithSong.accentBeats,
          regularBeats: stateWithSong.regularBeats,
          beatModes: stateWithSong.beatModes,
          loadedSong: null,
          loadedSetlist: null,
          currentSetlistIndex: 0,
        );

        expect(clearedState.loadedSong, isNull);
      });

      test('creates new state with null loadedSetlist', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        // Create state with loaded setlist
        final stateWithSetlist = MetronomeState.initial().copyWith(
          loadedSetlist: setlist,
        );
        expect(stateWithSetlist.loadedSetlist, isNotNull);

        // Create new state without loaded setlist
        final clearedState = MetronomeState(
          isPlaying: stateWithSetlist.isPlaying,
          bpm: stateWithSetlist.bpm,
          currentBeat: stateWithSetlist.currentBeat,
          timeSignature: stateWithSetlist.timeSignature,
          waveType: stateWithSetlist.waveType,
          volume: stateWithSetlist.volume,
          accentEnabled: stateWithSetlist.accentEnabled,
          accentFrequency: stateWithSetlist.accentFrequency,
          beatFrequency: stateWithSetlist.beatFrequency,
          accentPattern: stateWithSetlist.accentPattern,
          accentBeats: stateWithSetlist.accentBeats,
          regularBeats: stateWithSetlist.regularBeats,
          beatModes: stateWithSetlist.beatModes,
          loadedSong: null,
          loadedSetlist: null,
          currentSetlistIndex: 0,
        );

        expect(clearedState.loadedSetlist, isNull);
      });

      test('resets currentSetlistIndex', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        // Create state with setlist at index 2
        final state = MetronomeState.initial().copyWith(
          loadedSetlist: setlist,
          currentSetlistIndex: 2,
        );
        expect(state.currentSetlistIndex, 2);

        // Create cleared state with index 0
        final clearedState = MetronomeState(
          isPlaying: state.isPlaying,
          bpm: state.bpm,
          currentBeat: state.currentBeat,
          timeSignature: state.timeSignature,
          waveType: state.waveType,
          volume: state.volume,
          accentEnabled: state.accentEnabled,
          accentFrequency: state.accentFrequency,
          beatFrequency: state.beatFrequency,
          accentPattern: state.accentPattern,
          accentBeats: state.accentBeats,
          regularBeats: state.regularBeats,
          beatModes: state.beatModes,
          loadedSong: null,
          loadedSetlist: null,
          currentSetlistIndex: 0,
        );

        expect(clearedState.currentSetlistIndex, 0);
      });
    });

    group('setAccentBeats/setRegularBeats simulation', () {
      test('sets accentBeats with clamping', () {
        var state = MetronomeState.initial();

        // Simulate setAccentBeats
        final count = 6;
        state = state.copyWith(accentBeats: count.clamp(1, 12));

        expect(state.accentBeats, 6);
      });

      test('clamps accentBeats to maximum', () {
        var state = MetronomeState.initial();

        final count = 20; // Too high
        state = state.copyWith(accentBeats: count.clamp(1, 12));

        expect(state.accentBeats, 12);
      });

      test('clamps accentBeats to minimum', () {
        var state = MetronomeState.initial();

        final count = 0; // Too low
        state = state.copyWith(accentBeats: count.clamp(1, 12));

        expect(state.accentBeats, 1);
      });

      test('sets regularBeats with clamping', () {
        var state = MetronomeState.initial();

        final count = 4;
        state = state.copyWith(regularBeats: count.clamp(1, 12));

        expect(state.regularBeats, 4);
      });
    });

    group('setBeatMode simulation', () {
      test('sets beat mode at specified position', () {
        var state = MetronomeState.initial();

        // Simulate setBeatMode
        final newBeatModes = List<List<BeatMode>>.from(
          state.beatModes.map((beat) => List<BeatMode>.from(beat)),
        );

        while (newBeatModes.length <= 0) {
          newBeatModes.add([]);
        }
        while (newBeatModes[0].length <= 0) {
          newBeatModes[0].add(BeatMode.normal);
        }
        newBeatModes[0][0] = BeatMode.accent;

        state = state.copyWith(beatModes: List.unmodifiable(newBeatModes));

        expect(state.beatModes.length, 1);
        expect(state.beatModes[0][0], BeatMode.accent);
      });

      test('expands beatModes grid when needed', () {
        var state = MetronomeState.initial();

        final beatIndex = 3;
        final subdivisionIndex = 2;

        final newBeatModes = List<List<BeatMode>>.from(
          state.beatModes.map((beat) => List<BeatMode>.from(beat)),
        );

        while (newBeatModes.length <= beatIndex) {
          newBeatModes.add([]);
        }
        while (newBeatModes[beatIndex].length <= subdivisionIndex) {
          newBeatModes[beatIndex].add(BeatMode.normal);
        }
        newBeatModes[beatIndex][subdivisionIndex] = BeatMode.silent;

        state = state.copyWith(beatModes: List.unmodifiable(newBeatModes));

        expect(state.beatModes.length, 4);
        expect(state.beatModes[3].length, 3);
        expect(state.beatModes[3][2], BeatMode.silent);
      });
    });

    group('Integration: load and save round-trip', () {
      test('round-trip: load settings, modify, save preserves changes', () {
        final originalBeatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.normal, BeatMode.normal],
          [BeatMode.normal, BeatMode.normal],
          [BeatMode.normal, BeatMode.normal],
        ];

        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          ourBPM: 100,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          accentBeats: 4,
          regularBeats: 2,
          beatModes: originalBeatModes,
        );

        // Load song
        var state = MetronomeState.initial();
        state = state.copyWith(loadedSong: song);
        state = state.copyWith(bpm: 100);
        state = state.copyWith(
          accentBeats: song.accentBeats,
          regularBeats: song.regularBeats,
        );

        // Modify settings
        state = state.copyWith(accentBeats: 6);
        state = state.copyWith(regularBeats: 3);
        state = state.copyWith(bpm: 140);

        final newBeatModes = List<List<BeatMode>>.from(
          state.beatModes.map((beat) => List<BeatMode>.from(beat)),
        );
        while (newBeatModes.length <= 0) newBeatModes.add([]);
        while (newBeatModes[0].length <= 0)
          newBeatModes[0].add(BeatMode.normal);
        newBeatModes[0][0] = BeatMode.silent;
        state = state.copyWith(beatModes: List.unmodifiable(newBeatModes));

        // Save
        final songToSave = state.loadedSong;
        Song? updatedSong;
        if (songToSave != null) {
          updatedSong = songToSave.copyWith(
            accentBeats: state.accentBeats,
            regularBeats: state.regularBeats,
            beatModes: state.beatModes,
            ourBPM: state.bpm,
            updatedAt: DateTime.now(),
          );
        }

        expect(updatedSong!.accentBeats, 6);
        expect(updatedSong.regularBeats, 3);
        expect(updatedSong.ourBPM, 140);
      });
    });
  });
}
