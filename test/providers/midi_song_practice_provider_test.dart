import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/section_span.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/backing_transport_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_practice_provider.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flowgroove/services/audio/midi/midi_song_player.dart';
import 'package:flowgroove/services/audio/midi/midi_track_renderer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backing_transport_test.dart' show FakeBackingEngine;

class _Metronome extends MetronomeNotifier {
  @override
  MetronomeState build() => MetronomeState.initial().copyWith(bpm: 120);

  void playing({required bool value}) =>
      state = state.copyWith(isPlaying: value);
  @override
  void start() => playing(value: true);

  void bpm(int value) => state = state.copyWith(bpm: value);
}

class _Player implements MidiSongPlayer {
  final loads = <List<Int16List>>[];
  final gains = <int, double>{};
  int? loadedSampleRate;
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
    loadedSampleRate = sampleRate;
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
  late FakeBackingEngine engine;
  late _Metronome metronome;
  late SongLabEntry entry;
  late MidiSongPracticeNotifier notifier;
  late bool failFetch;
  late int fetches;
  Completer<Uint8List>? pendingFetch;

  MidiSongPracticeState current() =>
      container.read(midiSongPracticeProvider(entry));

  setUp(() {
    engine = FakeBackingEngine();
    player = _Player();
    metronome = _Metronome();
    failFetch = false;
    fetches = 0;
    pendingFetch = null;
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
        backingEngineProvider.overrideWithValue(engine),
        useBackingTransportProvider.overrideWithValue(false),
        metronomeProvider.overrideWith(() => metronome),
        midiSongPlayerProvider.overrideWith((ref, entry) => player),
        midiSongBytesFetcherProvider.overrideWithValue((url) async {
          fetches++;
          if (failFetch) throw StateError('fetch failed');
          if (pendingFetch != null) return pendingFetch!.future;
          return _smf();
        }),
      ],
    )..listen(midiSongPracticeProvider(entry), (_, _) {});
    notifier = container.read(midiSongPracticeProvider(entry).notifier);
    addTearDown(() async {
      container.dispose();
      await pumpEventQueue();
      await engine.dispose();
    });
  });

  Future<void> useBacking() async {
    container.dispose();
    await pumpEventQueue();
    metronome = _Metronome();
    container = ProviderContainer(
      overrides: [
        backingEngineProvider.overrideWithValue(engine),
        useBackingTransportProvider.overrideWithValue(true),
        metronomeProvider.overrideWith(() => metronome),
        midiSongPlayerProvider.overrideWith(
          (ref, entry) => throw StateError('Legacy player must not be created'),
        ),
        midiSongBytesFetcherProvider.overrideWithValue((url) async => _smf()),
      ],
    )..listen(midiSongPracticeProvider(entry), (_, _) {});
    notifier = container.read(midiSongPracticeProvider(entry).notifier);
    await notifier.loadEntry();
    expect(current().error, isNull);
  }

  test(
    'backing path parses roles and attaches without starting audio',
    () async {
      await useBacking();
      expect(current().tracks.map((track) => track.index), [1, 2]);
      expect(current().tracks.first.effectiveRole, MidiRole.bass);
      expect(current().tracks.first.volume, 0.4);
      expect(engine.loads.single.names, [
        'Acoustic Grand Piano · ch 1',
        'Acoustic Grand Piano · ch 2',
      ]);
      expect(engine.gains, {0: 0.4, 1: 1.0});
      expect(engine.commands, isEmpty);
      expect(current().loading, isFalse);
    },
  );

  test('backing mixer applies per-track volume, mute and solo live', () async {
    await useBacking();
    notifier.setVolume(0, 0);
    expect(engine.gains, {0: 0.0, 1: 1.0});
    notifier
      ..setVolume(0, 0.5)
      ..setMute(1, mute: true);
    expect(engine.gains, {0: 0.5, 1: 0.0});
    notifier
      ..setMute(1, mute: false)
      ..toggleSolo(1);
    expect(current().soloed, {1});
    expect(engine.gains, {0: 0.0, 1: 1.0});
    // Gains are live: no re-render, no transport command.
    expect(engine.loads, hasLength(1));
    expect(engine.commands, isEmpty);
  });

  test('tracks with the same name keep independent mute and solo', () async {
    final bass = entry.midiSong!.tracks.single;
    entry = entry.copyWith(
      midiSong: entry.midiSong!.copyWith(
        tracks: [bass, bass.copyWith(index: 2, channel: 1, volume: 0.8)],
      ),
    );
    await useBacking();
    expect(engine.loads.single.names, hasLength(2));
    notifier.setMute(1, mute: true);
    expect(engine.gains[1], 0);
    expect(engine.gains[0], isNot(0));
    notifier
      ..setMute(1, mute: false)
      ..toggleSolo(0);
    expect(engine.gains[1], 0);
    expect(current().tracks[1].mute, isFalse);
    expect(current().tracks[1].volume, 0.8);
  });

  test(
    'backing attach and persisted edits preserve spans and file tempo',
    () async {
      const span = SectionSpan(sectionId: 'verse', startBar: 3, bars: 2);
      entry = entry.copyWith(
        midiSong: entry.midiSong!.copyWith(
          sectionMap: [span],
          useFileTempo: true,
        ),
      );
      await useBacking();
      final saved = <SongLabEntry>[];
      await notifier.loadEntry(onPersist: saved.add);
      expect(container.read(backingTransportProvider).spans, [span]);
      metronome.bpm(180);
      await _until(() => engine.loads.length == 3 && !current().loading);
      expect(engine.loads.last.renderBpm, 180);
      notifier.setVolume(0, 0.6);
      await pumpEventQueue();
      expect(saved.single.midiSong!.sectionMap, [span]);
      expect(saved.single.midiSong!.useFileTempo, isTrue);
    },
  );

  test('big Play launches backing once and Stop uses the transport', () async {
    await useBacking();
    metronome.playing(value: true);
    await _until(() => engine.commands.isNotEmpty);
    expect(engine.commands, hasLength(1));
    engine.playing(engine.commands.single);
    expect(current().playing, isTrue);
    metronome.playing(value: false);
    await pumpEventQueue();
    expect(engine.commands, hasLength(2));
    expect(current().playing, isFalse);
  });

  test('pad launch does not also launch the first span', () async {
    await useBacking();
    await container.read(backingTransportProvider.notifier).launch('song');
    await pumpEventQueue();
    expect(engine.commands, hasLength(1));
    expect(container.read(metronomeProvider).isPlaying, isTrue);
  });

  test('backing tempo changes are rendered only by the transport', () async {
    await useBacking();
    metronome.bpm(180);
    await _until(() => engine.loads.length == 2 && !current().loading);
    expect(engine.loads.last.renderBpm, 180);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(engine.loads, hasLength(2));
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
            sampleRate: 22050,
          ),
        ),
      );
      expect(player.loadedSampleRate, 22050);
      expect(current().skippedTracks, isEmpty);
      expect(current().notice, isNull);
      expect(fetches, 1);
      expect(current().playing, isFalse);
    },
  );

  Future<void> loadSong(MidiSongData song) async {
    container.dispose();
    await pumpEventQueue();
    metronome = _Metronome();
    player = _Player();
    container = ProviderContainer(
      overrides: [
        backingEngineProvider.overrideWithValue(engine),
        useBackingTransportProvider.overrideWithValue(false),
        metronomeProvider.overrideWith(() => metronome),
        midiSongPlayerProvider.overrideWith((ref, entry) => player),
        midiSongProvider(entry).overrideWith((ref) async => song),
      ],
    )..listen(midiSongPracticeProvider(entry), (_, _) {});
    notifier = container.read(midiSongPracticeProvider(entry).notifier);
    await notifier.loadEntry();
    expect(current().error, isNull);
  }

  test(
    'selects 12 busiest tracks and keeps buffer and control order',
    () async {
      final song = MidiSongData(
        ppq: 96,
        tempos: [],
        timeSigs: [],
        tracks: [
          for (var i = 0; i < 14; i++)
            MidiTrackData(
              index: i + 20,
              name: 'Track $i',
              channel: 9,
              program: 0,
              notes: [
                for (var n = 0; n <= i; n++)
                  MidiNote(tick: n, dur: 1, pitch: 36, vel: 100),
              ],
            ),
        ],
      );
      await loadSong(song);
      expect(current().tracks, hasLength(14));
      expect(current().skippedTracks, {0, 1});
      expect(current().notice, contains('2 tracks skipped'));
      expect(current().gains.take(2), [0, 0]);
      expect(player.loads.single, hasLength(12));
      for (var i = 0; i < 12; i++) {
        expect(
          player.loads.single[i],
          orderedEquals(
            renderMidiTrack(
              song: song,
              track: song.tracks[i + 2],
              role: MidiRole.drums,
              sampleRate: 22050,
            ),
          ),
        );
      }
      notifier.setVolume(2, 0.3);
      expect(player.gains[0], 0.3);
      notifier.setVolume(0, 0.8);
      expect(current().gains[0], 0);
      expect(player.gains[0], 0.3);
      notifier.toggleSolo(3);
      expect(player.gains[0], 0);
      expect(player.gains[1], 1);
      expect(current().skippedTracks, {0, 1});
    },
  );

  test(
    'skips long tracks before rendering when total frames exceed budget',
    () async {
      await loadSong(
        MidiSongData(
          ppq: 96,
          tempos: const [
            TempoChange(tick: 0, microsPerQuarter: 500000),
            TempoChange(tick: 96, microsPerQuarter: 1000000),
          ],
          timeSigs: [],
          tracks: [
            for (var i = 0; i < 4; i++)
              MidiTrackData(
                index: i,
                name: '',
                channel: 9,
                program: 0,
                notes: [
                  MidiNote(
                    tick: i == 3 ? 0 : 57600,
                    dur: i == 3 ? 1 : 200,
                    pitch: 1,
                    vel: 100,
                  ),
                ],
              ),
          ],
        ),
      );
      expect(current().skippedTracks, {2});
      expect(current().gains, [1, 1, 0, 1]);
      final buffers = player.loads.single;
      expect(buffers, hasLength(3));
      expect(buffers[0].length, 13230000);
      expect(buffers[1].length, 13230000);
      expect(
        buffers.fold<int>(0, (sum, buffer) => sum + buffer.length),
        lessThanOrEqualTo(30000000),
      );
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
    final song = (await container.read(midiSongProvider(entry).future))!;
    expect(song.initialBpm, 120);
    notifier.setMute(1, mute: true);
    metronome
      ..bpm(180)
      ..bpm(240);
    expect(player.loads, hasLength(1));
    await _until(() => player.loads.length == 2 && !current().loading);
    expect(
      player.loads.last.first,
      orderedEquals(
        renderMidiTrack(
          song: song,
          track: song.tracks.first,
          role: MidiRole.bass,
          sampleRate: 22050,
          bpmScale: 2,
        ),
      ),
    );
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
      final song = (await container.read(midiSongProvider(entry).future))!;
      expect(song.initialBpm, 120);
      expect(
        player.loads.last.first,
        orderedEquals(
          renderMidiTrack(
            song: song,
            track: song.tracks.first,
            role: MidiRole.bass,
            sampleRate: 22050,
            bpmScale: 2,
          ),
        ),
      );
      expect(player.starts, 1);
    },
  );

  test('BPM scale uses the tempo at tick zero or the default 120', () async {
    for (final tempoTick in [0, 96]) {
      const track = MidiTrackData(
        index: 1,
        name: '',
        channel: 0,
        program: 0,
        notes: [MidiNote(tick: 0, dur: 192, pitch: 60, vel: 100)],
      );
      final song = MidiSongData(
        ppq: 96,
        tempos: [TempoChange(tick: tempoTick, microsPerQuarter: 400000)],
        timeSigs: [],
        tracks: [track],
      );
      await loadSong(song);
      expect(song.initialBpm, tempoTick == 0 ? 150 : 120);
      expect(
        player.loads.single.single,
        orderedEquals(
          renderMidiTrack(
            song: song,
            track: track,
            role: MidiRole.bass,
            sampleRate: 22050,
            bpmScale: tempoTick == 0 ? 120 / 150 : 1,
          ),
        ),
      );
    }
  });

  test('stop during a pending fetch still loads tracks', () async {
    final pending = pendingFetch = Completer<Uint8List>();
    metronome.playing(value: true);
    final loading = notifier.loadEntry();
    await _until(() => fetches == 1);
    metronome.playing(value: false);
    pending.complete(_smf());
    await loading;
    expect(current().tracks, hasLength(2));
    expect(player.loads.single, hasLength(2));
    expect(current().loading, isFalse);
    expect(current().error, isNull);
    expect(current().playing, isFalse);
    expect(player.starts, 0);
  });

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

  test('a newer entry load supersedes a pending fetch', () async {
    final pending = pendingFetch = Completer<Uint8List>();
    final first = notifier.loadEntry();
    await _until(() => fetches == 1);
    final second = notifier.loadEntry();
    await pumpEventQueue();
    pending.complete(_smf());
    await Future.wait([first, second]);
    expect(current().tracks, hasLength(2));
    expect(player.loads, hasLength(1));
    expect(current().loading, isFalse);
    expect(current().error, isNull);
  });

  test('dispose discards a pending fetch', () async {
    final pending = pendingFetch = Completer<Uint8List>();
    final loading = notifier.loadEntry();
    await _until(() => fetches == 1);
    container.dispose();
    pending.complete(_smf());
    await loading;
    await pumpEventQueue();
    expect(player.loads, isEmpty);
    expect(player.disposed, isTrue);
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
