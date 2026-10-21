import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_practice_provider.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flowgroove/services/audio/midi/midi_song_player.dart';
import 'package:flowgroove/services/audio/midi/midi_track_renderer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Metronome extends MetronomeNotifier {
  @override
  MetronomeState build() => MetronomeState.initial().copyWith(bpm: 120);

  void playing({required bool value}) =>
      state = state.copyWith(isPlaying: value);
  void bpm(int value) => state = state.copyWith(bpm: value);
}

class _Player implements MidiSongPlayer {
  final loads = <List<Int16List>>[];
  final gains = <int, double>{};
  int starts = 0;
  int stops = 0;
  bool disposed = false;
  bool failLoad = false;
  bool failStart = false;
  bool failStop = false;
  Completer<void>? pendingLoad;

  @override
  Duration get position => Duration.zero;

  @override
  Future<void> load(List<Int16List> buffers, {int sampleRate = 44100}) async {
    if (failLoad) throw StateError('load failed');
    loads.add(buffers);
    await pendingLoad?.future;
  }

  @override
  Future<void> start() async {
    if (failStart) throw StateError('start failed');
    starts++;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('stop failed');
  }

  @override
  void setTrackGain(int index, double gain) => gains[index] = gain;

  @override
  Future<void> dispose() async => disposed = true;
}

Uint8List _smf() => Uint8List.fromList([
  ...'MThd'.codeUnits,
  0,
  0,
  0,
  6,
  0,
  1,
  0,
  3,
  0,
  96,
  // A conductor track makes source indices differ from buffer positions.
  ...'MTrk'.codeUnits,
  0, 0, 0, 4,
  0, 0xff, 0x2f, 0,
  for (var channel = 0; channel < 2; channel++) ...[
    ...'MTrk'.codeUnits,
    0,
    0,
    0,
    12,
    0,
    0x90 + channel,
    60,
    100,
    24,
    0x80 + channel,
    60,
    0,
    0,
    0xff,
    0x2f,
    0,
  ],
]);

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for playback');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late ProviderContainer container;
  late _Player player;
  late _Metronome metronome;
  late SongLabEntry entry;
  late MidiSongPracticeNotifier notifier;
  late bool failFetch;
  late int fetches;

  MidiSongPracticeState current() =>
      container.read(midiSongPracticeProvider(entry));

  setUp(() {
    player = _Player();
    metronome = _Metronome();
    failFetch = false;
    fetches = 0;
    entry = SongLabEntry(
      id: 'entry',
      songId: 'song',
      type: LabEntryType.midi,
      authorId: 'author',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      midiSong: const MidiSongMeta(
        fileUrl: 'https://example.com/song.mid',
        ppq: 96,
        initialBpm: 120,
        tracks: [
          MidiTrackMeta(
            index: 1,
            name: '',
            channel: 0,
            program: 0,
            detectedRole: MidiRole.keys,
            roleOverride: MidiRole.bass,
            volume: 0.4,
            noteCount: 1,
            minPitch: 60,
            maxPitch: 60,
          ),
        ],
      ),
    );
    container = ProviderContainer(
      overrides: [
        metronomeProvider.overrideWith(() => metronome),
        midiSongPlayerProvider.overrideWith((ref, entry) => player),
        midiSongBytesFetcherProvider.overrideWithValue((url) async {
          fetches++;
          if (failFetch) throw StateError('fetch failed');
          return _smf();
        }),
      ],
    )..listen(midiSongPracticeProvider(entry), (_, _) {});
    notifier = container.read(midiSongPracticeProvider(entry).notifier);
    addTearDown(() async {
      container.dispose();
      await pumpEventQueue();
    });
  });

  test(
    'loads every track with saved roles and volume in buffer order',
    () async {
      expect(current().tracks, isEmpty);
      final loading = notifier.loadEntry();
      expect(current().loading, isTrue);
      await loading;
      expect(current().loading, isFalse);
      expect(current().error, isNull);
      expect(current().tracks, hasLength(2));
      expect(current().tracks.map((track) => track.index), [1, 2]);
      expect(current().tracks.first.effectiveRole, MidiRole.bass);
      expect(player.gains, {0: 0.4, 1: 1.0});
      expect(player.loads.single, hasLength(2));
      final song = (await container.read(midiSongProvider(entry).future))!;
      expect(
        player.loads.single.first,
        orderedEquals(
          renderMidiTrack(
            song: song,
            track: song.tracks.first,
            role: MidiRole.bass,
          ),
        ),
      );
      expect(fetches, 1);
      expect(current().playing, isFalse);
    },
  );

  test('mute and volume update gains and persist an updated entry', () async {
    final saved = <SongLabEntry>[];
    await notifier.loadEntry(onPersist: saved.add);
    final before = current();
    notifier.setMute(0, mute: true);
    expect(player.gains[0], 0);
    expect(before.tracks.first.mute, isFalse);
    notifier.setVolume(0, 0.7);
    expect(player.gains[0], 0);
    notifier.setMute(0, mute: false);
    expect(player.gains[0], 0.7);
    await pumpEventQueue();
    expect(saved, hasLength(3));
    expect(saved.last.midiSong!.tracks.first.volume, 0.7);
    expect(saved.last.midiSong!.tracks.first.mute, isFalse);
    expect(saved.last.midiSong!.fileUrl, entry.midiSong!.fileUrl);
    expect(entry.midiSong!.tracks.first.volume, 0.4);
  });

  test('solo silences other tracks and continues to respect mute', () async {
    await notifier.loadEntry();
    notifier.toggleSolo(0);
    expect(current().soloed, {0});
    expect(player.gains, {0: 0.4, 1: 0.0});
    notifier.toggleSolo(1);
    expect(player.gains, {0: 0.4, 1: 1.0});
    notifier.setMute(0, mute: true);
    expect(player.gains[0], 0);
    notifier.toggleSolo(0);
    expect(player.gains, {0: 0.0, 1: 1.0});
    notifier.toggleSolo(1);
    expect(current().soloed, isEmpty);
    expect(player.gains, {0: 0.0, 1: 1.0});
  });

  test('metronome starts and stops the player', () async {
    await notifier.loadEntry();
    metronome.playing(value: true);
    await _until(() => current().playing);
    expect(player.starts, 1);
    final stops = player.stops;
    metronome.playing(value: false);
    await pumpEventQueue();
    expect(current().playing, isFalse);
    expect(player.stops, stops + 1);
  });

  test(
    'loading while metronome runs starts playback after rendering',
    () async {
      metronome.playing(value: true);
      await notifier.loadEntry();
      expect(player.starts, 1);
      expect(current().playing, isTrue);
    },
  );

  test('stopped BPM changes debounce and render at the latest scale', () async {
    await notifier.loadEntry();
    final length = player.loads.single.first.length;
    notifier.setMute(1, mute: true);
    metronome
      ..bpm(180)
      ..bpm(240);
    expect(player.loads, hasLength(1));
    await _until(() => player.loads.length == 2 && !current().loading);
    expect(player.loads.last.first.length, length ~/ 2);
    expect(player.gains[1], 0);
    expect(player.starts, 0);
    expect(fetches, 1);
  });

  test(
    'starting before debounce renders current BPM and starts once',
    () async {
      await notifier.loadEntry();
      metronome
        ..bpm(240)
        ..playing(value: true);
      await _until(() => current().playing);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(player.loads, hasLength(2));
      expect(
        player.loads.last.first.length,
        player.loads.first.first.length ~/ 2,
      );
      expect(player.starts, 1);
    },
  );

  test('stop during a pending load prevents a late start', () async {
    final pending = player.pendingLoad = Completer<void>();
    metronome.playing(value: true);
    final loading = notifier.loadEntry();
    await _until(() => player.loads.isNotEmpty);
    metronome.playing(value: false);
    pending.complete();
    await loading;
    expect(player.starts, 0);
    expect(current().playing, isFalse);
    expect(current().loading, isFalse);
  });

  test('fetch failures surface in state', () async {
    failFetch = true;
    await notifier.loadEntry();
    expect(current().error, contains('fetch failed'));
    expect(current().loading, isFalse);
    expect(current().playing, isFalse);
  });

  test('player load failures surface in state', () async {
    player.failLoad = true;
    await notifier.loadEntry();
    expect(current().error, contains('load failed'));
    expect(current().loading, isFalse);
    expect(current().playing, isFalse);
  });

  test('start and stop failures surface in state', () async {
    await notifier.loadEntry();
    player.failStart = true;
    metronome.playing(value: true);
    await _until(() => current().error != null);
    expect(current().error, contains('start failed'));
    expect(current().playing, isFalse);
    player.failStop = true;
    await notifier.stop();
    expect(current().error, contains('stop failed'));
  });

  test('persistence failures surface in state', () async {
    await notifier.loadEntry(
      onPersist: (_) async => throw StateError('save failed'),
    );
    notifier.setMute(0, mute: true);
    await pumpEventQueue();
    expect(current().error, contains('save failed'));
    expect(player.gains[0], 0);
  });

  test('dispose stops and disposes the player', () async {
    await notifier.loadEntry();
    metronome.playing(value: true);
    await _until(() => current().playing);
    final stops = player.stops;
    container.dispose();
    await pumpEventQueue();
    expect(player.stops, stops + 1);
    expect(player.disposed, isTrue);
  });
}
