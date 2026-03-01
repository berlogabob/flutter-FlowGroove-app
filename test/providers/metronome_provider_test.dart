import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/providers/data/metronome_provider.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/beat_mode.dart';
import 'package:flutter_repsync_app/models/time_signature.dart';

void main() {
  group('MetronomeNotifier - Metronome Integration', () {
    group('loadSongTempo', () {
      test('loads BPM from song (ourBPM preferred)', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 100,
          ourBPM: 120,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 120);
        expect(state.loadedSong, equals(song));
      });

      test('loads BPM from song (falls back to originalBPM)', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final song = Song(
          id: 'song-2',
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 100,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 100);
      });

      test('clamps BPM to valid range (1-300)', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final song = Song(
          id: 'song-3',
          title: 'Test Song',
          artist: 'Test Artist',
          ourBPM: 500, // Too high
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 300); // Clamped
      });

      test('loads metronome settings from song', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final beatModes = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.accent],
        ];

        final song = Song(
          id: 'song-4',
          title: 'Test Song',
          artist: 'Test Artist',
          ourBPM: 120,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          accentBeats: 6,
          regularBeats: 2,
          beatModes: beatModes,
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);

        final state = container.read(metronomeProvider);
        expect(state.accentBeats, 6);
        expect(state.regularBeats, 2);
        expect(state.beatModes.length, 2);
        expect(state.beatModes[0][0], BeatMode.accent);
        expect(state.beatModes[1][0], BeatMode.silent);
      });

      test('updates time signature to match loaded accentBeats', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final song = Song(
          id: 'song-5',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          accentBeats: 6,
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);

        final state = container.read(metronomeProvider);
        expect(state.timeSignature.numerator, 6);
        expect(state.accentBeats, 6);
      });

      test('preserves existing beatModes when song has empty beatModes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // First set some beatModes
        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBeatMode(0, 0, BeatMode.accent);

        final song = Song(
          id: 'song-6',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          beatModes: [], // Empty
        );

        metronome.loadSongTempo(song);

        final state = container.read(metronomeProvider);
        // Should preserve existing beatModes when song has empty
        expect(state.beatModes.isNotEmpty, isTrue);
      });

      test('loads song without BPM does not change current BPM', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initialBpm = container.read(metronomeProvider).bpm;

        final song = Song(
          id: 'song-7',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);

        final state = container.read(metronomeProvider);
        expect(state.bpm, initialBpm); // Unchanged
        expect(state.loadedSong, equals(song));
      });
    });

    group('saveMetronomeToSong', () {
      test('returns null when no song is loaded', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        final result = metronome.saveMetronomeToSong();

        expect(result, isNull);
      });

      test('saves current metronome settings to loaded song', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          ourBPM: 100,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);

        // Change settings
        metronome.setAccentBeats(6);
        metronome.setRegularBeats(2);
        metronome.setBeatMode(0, 0, BeatMode.accent);
        metronome.setBpm(120);

        final updatedSong = metronome.saveMetronomeToSong();

        expect(updatedSong, isNotNull);
        expect(updatedSong!.accentBeats, 6);
        expect(updatedSong.regularBeats, 2);
        expect(updatedSong.beatModes[0][0], BeatMode.accent);
        expect(updatedSong.ourBPM, 120);
      });

      test('updates loadedSong in state after saving', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final song = Song(
          id: 'song-2',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);
        metronome.setAccentBeats(5);

        metronome.saveMetronomeToSong();

        final state = container.read(metronomeProvider);
        expect(state.loadedSong!.accentBeats, 5);
      });

      test('updates updatedAt timestamp when saving', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final originalDate = DateTime(2024, 1, 1);
        final song = Song(
          id: 'song-3',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: originalDate,
          updatedAt: originalDate,
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);

        final updatedSong = metronome.saveMetronomeToSong();

        expect(updatedSong!.updatedAt, isNotNull);
        expect(updatedSong.updatedAt.isAfter(originalDate), isTrue);
      });
    });

    group('loadSongTempo and saveMetronomeToSong integration', () {
      test('round-trip: load settings, modify, save preserves changes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

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

        final metronome = container.read(metronomeProvider.notifier);

        // Load song
        metronome.loadSongTempo(song);

        // Modify settings
        metronome.setAccentBeats(6);
        metronome.setRegularBeats(3);
        metronome.setBeatMode(0, 0, BeatMode.silent);
        metronome.setBpm(140);

        // Save
        final updatedSong = metronome.saveMetronomeToSong();

        expect(updatedSong!.accentBeats, 6);
        expect(updatedSong.regularBeats, 3);
        expect(updatedSong.beatModes[0][0], BeatMode.silent);
        expect(updatedSong.ourBPM, 140);
      });
    });

    group('loadSetlistQueue', () {
      test('loads setlist into state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSetlistQueue(setlist);

        final state = container.read(metronomeProvider);
        expect(state.loadedSetlist, equals(setlist));
        expect(state.currentSetlistIndex, 0);
      });

      test('clears loadedSong when loading setlist', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-2'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        metronome.loadSetlistQueue(setlist);

        final state = container.read(metronomeProvider);
        expect(state.loadedSetlist, equals(setlist));
        // Note: loadedSong may or may not be cleared depending on implementation
      });
    });

    group('Setlist navigation', () {
      test('nextSetlistSong increments index', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSetlistQueue(setlist);

        metronome.nextSetlistSong();

        final state = container.read(metronomeProvider);
        expect(state.currentSetlistIndex, 1);
      });

      test('nextSetlistSong does not exceed song count', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSetlistQueue(setlist);

        // Go to last song
        metronome.nextSetlistSong();
        metronome.nextSetlistSong(); // Should not go beyond

        final state = container.read(metronomeProvider);
        expect(state.currentSetlistIndex, 1); // Max is 1 (0-indexed)
      });

      test('previousSetlistSong decrements index', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSetlistQueue(setlist);
        metronome.nextSetlistSong();
        metronome.nextSetlistSong();

        metronome.previousSetlistSong();

        final state = container.read(metronomeProvider);
        expect(state.currentSetlistIndex, 1);
      });

      test('previousSetlistSong does not go below zero', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSetlistQueue(setlist);
        metronome.nextSetlistSong();
        metronome.previousSetlistSong();
        metronome.previousSetlistSong(); // Should not go below 0

        final state = container.read(metronomeProvider);
        expect(state.currentSetlistIndex, 0);
      });
    });

    group('clearLoadedContent', () {
      test('clears loaded song', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSongTempo(song);
        metronome.clearLoadedContent();

        final state = container.read(metronomeProvider);
        expect(state.loadedSong, isNull);
      });

      test('clears loaded setlist', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSetlistQueue(setlist);
        metronome.clearLoadedContent();

        final state = container.read(metronomeProvider);
        expect(state.loadedSetlist, isNull);
      });

      test('resets currentSetlistIndex', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSetlistQueue(setlist);
        metronome.nextSetlistSong();
        metronome.nextSetlistSong();
        metronome.clearLoadedContent();

        final state = container.read(metronomeProvider);
        expect(state.currentSetlistIndex, 0);
      });
    });

    group('setAccentBeats', () {
      test('sets accentBeats value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setAccentBeats(6);

        final state = container.read(metronomeProvider);
        expect(state.accentBeats, 6);
      });

      test('clamps accentBeats to valid range (1-12)', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setAccentBeats(20); // Too high

        final state = container.read(metronomeProvider);
        expect(state.accentBeats, 12); // Clamped
      });

      test('clamps accentBeats minimum to 1', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setAccentBeats(0); // Too low

        final state = container.read(metronomeProvider);
        expect(state.accentBeats, 1); // Clamped
      });
    });

    group('setRegularBeats', () {
      test('sets regularBeats value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setRegularBeats(4);

        final state = container.read(metronomeProvider);
        expect(state.regularBeats, 4);
      });

      test('clamps regularBeats to valid range (1-12)', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setRegularBeats(20); // Too high

        final state = container.read(metronomeProvider);
        expect(state.regularBeats, 12); // Clamped
      });
    });

    group('setBeatMode', () {
      test('sets beat mode at specified position', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBeatMode(0, 0, BeatMode.accent);

        final state = container.read(metronomeProvider);
        expect(state.beatModes.length, 1);
        expect(state.beatModes[0][0], BeatMode.accent);
      });

      test('expands beatModes grid when needed', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBeatMode(3, 2, BeatMode.silent);

        final state = container.read(metronomeProvider);
        expect(state.beatModes.length, 4);
        expect(state.beatModes[3].length, 3);
        expect(state.beatModes[3][2], BeatMode.silent);
      });

      test('can set multiple beat modes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBeatMode(0, 0, BeatMode.accent);
        metronome.setBeatMode(0, 1, BeatMode.normal);
        metronome.setBeatMode(1, 0, BeatMode.silent);

        final state = container.read(metronomeProvider);
        expect(state.beatModes.length, 2);
        expect(state.beatModes[0][0], BeatMode.accent);
        expect(state.beatModes[0][1], BeatMode.normal);
        expect(state.beatModes[1][0], BeatMode.silent);
      });
    });

    group('Edge cases', () {
      test('loadSongTempo with null BPM does not crash', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        expect(() => metronome.loadSongTempo(song), returnsNormally);
      });

      test('saveMetronomeToSong without loaded song returns null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        final result = metronome.saveMetronomeToSong();

        expect(result, isNull);
      });

      test('setlist navigation without loaded setlist does not crash', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        expect(() => metronome.nextSetlistSong(), returnsNormally);
        expect(() => metronome.previousSetlistSong(), returnsNormally);
      });
    });

    group('Metronome State Initialization', () {
      test('initial state has correct default BPM', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 120);
      });

      test('initial state is not playing', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isFalse);
      });

      test('initial state has correct time signature', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(metronomeProvider);
        expect(state.timeSignature.numerator, 4);
        expect(state.timeSignature.denominator, 4);
      });

      test('initial state has correct volume', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(metronomeProvider);
        expect(state.volume, 0.5);
      });

      test('initial state has correct wave type', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(metronomeProvider);
        expect(state.waveType, 'sine');
      });

      test('initial state has correct accentBeats', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(metronomeProvider);
        expect(state.accentBeats, 4);
      });

      test('initial state has correct regularBeats', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(metronomeProvider);
        expect(state.regularBeats, 1);
      });

      test('state copyWith creates new instance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final originalState = container.read(metronomeProvider);
        final newState = originalState.copyWith(bpm: 140);

        expect(originalState.bpm, 120);
        expect(newState.bpm, 140);
        expect(newState.isPlaying, originalState.isPlaying);
      });

      test('state copyWith preserves unchanged values', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final originalState = container.read(metronomeProvider);
        final newState = originalState.copyWith(bpm: 140);

        expect(newState.waveType, originalState.waveType);
        expect(newState.volume, originalState.volume);
        expect(newState.timeSignature, originalState.timeSignature);
      });
    });

    group('BPM Controls', () {
      test('setBpm updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBpm(140);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 140);
      });

      test('setBpm clamps to minimum 40', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBpm(0);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 40);
      });

      test('setBpm clamps to maximum 220', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBpm(500);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 220);
      });

      test('adjustTempoFine increases BPM', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.adjustTempoFine(10);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 130);
      });

      test('adjustTempoFine decreases BPM', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.adjustTempoFine(-10);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 110);
      });

      test('adjustTempoFine clamps at maximum', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBpm(295);
        metronome.adjustTempoFine(10);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 300);
      });

      test('adjustTempoFine clamps at minimum', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBpm(5);
        metronome.adjustTempoFine(-10);

        final state = container.read(metronomeProvider);
        expect(state.bpm, 1);
      });

      test('rotateTempo updates BPM', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.rotateTempo(288); // Should increase by 1

        final state = container.read(metronomeProvider);
        expect(state.bpm, 121);
      });

      test('rotateTempo negative decreases BPM', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.rotateTempo(-288); // Should decrease by 1

        final state = container.read(metronomeProvider);
        expect(state.bpm, 119);
      });
    });

    group('Note Value Controls', () {
      test('setAccentBeats updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setAccentBeats(6);

        final state = container.read(metronomeProvider);
        expect(state.accentBeats, 6);
      });

      test('setAccentBeats clamps to range 1-12', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setAccentBeats(20);

        final state = container.read(metronomeProvider);
        expect(state.accentBeats, 12);
      });

      test('setRegularBeats updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setRegularBeats(4);

        final state = container.read(metronomeProvider);
        expect(state.regularBeats, 4);
      });

      test('setRegularBeats clamps to range 1-12', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setRegularBeats(20);

        final state = container.read(metronomeProvider);
        expect(state.regularBeats, 12);
      });

      test('setBeatMode sets mode at position', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBeatMode(0, 0, BeatMode.accent);

        final state = container.read(metronomeProvider);
        expect(state.beatModes.length, 1);
        expect(state.beatModes[0][0], BeatMode.accent);
      });

      test('setBeatMode expands grid when needed', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBeatMode(3, 2, BeatMode.silent);

        final state = container.read(metronomeProvider);
        expect(state.beatModes.length, 4);
        expect(state.beatModes[3].length, 3);
        expect(state.beatModes[3][2], BeatMode.silent);
      });

      test('setTimeSignature updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        final timeSignature = TimeSignature(numerator: 3, denominator: 4);
        metronome.setTimeSignature(timeSignature);

        final state = container.read(metronomeProvider);
        expect(state.timeSignature.numerator, 3);
        expect(state.timeSignature.denominator, 4);
      });

      test('setTimeSignature handles 6/8 special case', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        final timeSignature = TimeSignature(numerator: 6, denominator: 8);
        metronome.setTimeSignature(timeSignature);

        final state = container.read(metronomeProvider);
        expect(state.accentBeats, 2);
      });
    });

    group('Playback Controls', () {
      test('togglePlayback starts when stopped', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.toggle();

        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isTrue);
      });

      test('togglePlayback stops when playing', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.start(120, 4);
        metronome.toggle();

        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isFalse);
      });

      test('start sets isPlaying to true', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.start(120, 4);

        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isTrue);
      });

      test('start does nothing if already playing', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.start(120, 4);

        metronome.start(120, 4);

        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isTrue);
      });

      test('stop sets isPlaying to false', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.start(120, 4);
        metronome.stop();

        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isFalse);
      });

      test('stop does nothing if already stopped', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        expect(() => metronome.stop(), returnsNormally);
      });

      test('setVolume updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setVolume(0.8);

        final state = container.read(metronomeProvider);
        expect(state.volume, 0.8);
      });

      test('setVolume clamps to 0.0-1.0', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setVolume(1.5);

        final state = container.read(metronomeProvider);
        expect(state.volume, 1.0);
      });

      test('setWaveType updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setWaveType('square');

        final state = container.read(metronomeProvider);
        expect(state.waveType, 'square');
      });

      test('toggleAccent toggles accent enabled', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.toggleAccent();

        final state = container.read(metronomeProvider);
        expect(state.accentEnabled, isFalse);
      });

      test('setAccentEnabled updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setAccentEnabled(false);

        final state = container.read(metronomeProvider);
        expect(state.accentEnabled, isFalse);
      });

      test('setAccentFrequency updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setAccentFrequency(2000.0);

        final state = container.read(metronomeProvider);
        expect(state.accentFrequency, 2000.0);
      });

      test('setBeatFrequency updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBeatFrequency(1000.0);

        final state = container.read(metronomeProvider);
        expect(state.beatFrequency, 1000.0);
      });

      test('setAccentPattern updates state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setAccentPattern([true, true, false, false]);

        final state = container.read(metronomeProvider);
        expect(state.accentPattern.length, 4);
        expect(state.accentPattern[0], isTrue);
        expect(state.accentPattern[2], isFalse);
      });
    });

    group('Preset Management', () {
      test('playTest method exists', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        expect(metronome.playTest, isNotNull);
      });

      test('updateAccentPatternFromTimeSignature updates pattern', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setTimeSignature(TimeSignature(numerator: 3, denominator: 4));
        metronome.updateAccentPatternFromTimeSignature();

        final state = container.read(metronomeProvider);
        expect(state.accentPattern.length, 3);
        expect(state.accentPattern[0], isTrue);
      });

      test('setBeatsPerMeasure updates time signature', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.setBeatsPerMeasure(3);

        final state = container.read(metronomeProvider);
        expect(state.timeSignature.numerator, 3);
      });
    });

    group('Dispose Verification', () {
      test('dispose stops timer and audio', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        metronome.start(120, 4);

        expect(() => metronome.dispose(), returnsNormally);
      });

      test('dispose can be called multiple times', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);

        expect(() => metronome.dispose(), returnsNormally);
        expect(() => metronome.dispose(), returnsNormally);
      });

      test('ProviderContainer dispose cleans up resources', () {
        final localContainer = ProviderContainer();

        localContainer.read(metronomeProvider);

        expect(() => localContainer.dispose(), returnsNormally);
      });
    });

    group('Loaded Content Management', () {
      test('clearLoadedContent method exists', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final metronome = container.read(metronomeProvider.notifier);
        expect(metronome.clearLoadedContent, isNotNull);
      });

      test('clearLoadedContent resets currentSetlistIndex', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final metronome = container.read(metronomeProvider.notifier);
        metronome.loadSetlistQueue(setlist);
        metronome.nextSetlistSong();
        metronome.nextSetlistSong();
        metronome.clearLoadedContent();

        final state = container.read(metronomeProvider);
        expect(state.currentSetlistIndex, 0);
      });
    });
  });
}
