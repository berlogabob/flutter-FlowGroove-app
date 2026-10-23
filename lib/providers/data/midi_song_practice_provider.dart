import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/midi_song.dart';
import '../../models/section.dart';
import '../../models/song_lab.dart';
import '../../services/audio/midi/midi_song_meta_builder.dart';
import '../../services/audio/midi/midi_song_player.dart';
import '../../services/audio/midi/midi_track_renderer.dart';
import 'backing_transport_provider.dart';
import 'metronome_provider.dart';
import 'midi_song_provider.dart';

class MidiSongPracticeState {
  const MidiSongPracticeState({
    this.loading = false,
    this.error,
    this.tracks = const [],
    this.playing = false,
    this.soloed = const {},
    this.skippedTracks = const {},
  });

  final bool loading;
  final String? error;
  final List<MidiTrackMeta> tracks;
  final bool playing;
  final Set<int> soloed;

  /// Positions in [tracks] omitted from playback to stay within the PCM budget.
  final Set<int> skippedTracks;

  String? get notice => skippedTracks.isEmpty
      ? null
      : '${skippedTracks.length} tracks skipped to limit playback memory.';

  List<double> get gains => [
    for (var i = 0; i < tracks.length; i++)
      if (skippedTracks.contains(i) ||
          tracks[i].mute ||
          (soloed.isNotEmpty && !soloed.contains(i)))
        0
      else
        tracks[i].volume,
  ];

  MidiSongPracticeState copyWith({
    bool? loading,
    String? error,
    List<MidiTrackMeta>? tracks,
    bool? playing,
    Set<int>? soloed,
    Set<int>? skippedTracks,
  }) => MidiSongPracticeState(
    loading: loading ?? this.loading,
    error: error,
    tracks: tracks == null ? this.tracks : List.unmodifiable(tracks),
    playing: playing ?? this.playing,
    soloed: soloed == null ? this.soloed : Set.unmodifiable(soloed),
    skippedTracks: skippedTracks == null
        ? this.skippedTracks
        : Set.unmodifiable(skippedTracks),
  );
}

final useBackingTransportProvider = Provider<bool>(
  (ref) => kIsWeb || defaultTargetPlatform == TargetPlatform.android,
);

final midiSongPlayerProvider = Provider.autoDispose
    .family<MidiSongPlayer, SongLabEntry>(
      (ref, entry) => createMidiSongPlayer(),
    );

typedef _RenderRequest = ({
  MidiSongData song,
  List<MidiTrackMeta> tracks,
  double bpmScale,
});

const _sampleRate = 22050;

typedef _RenderedTracks = ({List<Int16List> buffers, Set<int> skipped});

_RenderedTracks _renderTracks(_RenderRequest request) {
  final song = request.song;
  final tempos = [...song.tempos]..sort((a, b) => a.tick.compareTo(b.tick));
  double secondsAt(int tick) {
    var previousTick = 0;
    var microsPerQuarter = 500000;
    var micros = 0.0;
    for (final tempo in tempos) {
      if (tempo.tick > tick) break;
      micros += (tempo.tick - previousTick) * microsPerQuarter / song.ppq;
      previousTick = tempo.tick;
      microsPerQuarter = tempo.microsPerQuarter;
    }
    micros += (tick - previousTick) * microsPerQuarter / song.ppq;
    return micros / 1000000 / request.bpmScale;
  }

  // Match the renderer's note timing and 600-second clipping before allocating PCM.
  final lengths = [
    for (final track in song.tracks)
      track.notes.fold<int>(0, (length, note) {
        if (note.tick < 0 || note.dur <= 0) return length;
        final start = secondsAt(note.tick);
        if (start >= 600) return length;
        final end =
            (math.min(secondsAt(note.tick + note.dur), 600) * _sampleRate)
                .round();
        return end > (start * _sampleRate).round()
            ? math.max(length, end)
            : length;
      }),
  ];
  final ranked = List.generate(song.tracks.length, (i) => i)
    ..sort((a, b) {
      final byNotes = song.tracks[b].noteCount.compareTo(
        song.tracks[a].noteCount,
      );
      return byNotes == 0 ? a.compareTo(b) : byNotes;
    });
  final selected = <int>{};
  var frames = 0;
  for (final i in ranked) {
    if (selected.length >= 12 || frames + lengths[i] > 30000000) continue;
    selected.add(i);
    frames += lengths[i];
  }
  return (
    buffers: [
      for (var i = 0; i < song.tracks.length; i++)
        if (selected.contains(i))
          renderMidiTrack(
            song: song,
            track: song.tracks[i],
            role: request.tracks[i].effectiveRole,
            sampleRate: _sampleRate,
            bpmScale: request.bpmScale,
          ),
    ],
    skipped: {
      for (var i = 0; i < song.tracks.length; i++)
        if (!selected.contains(i)) i,
    },
  );
}

class MidiSongPracticeNotifier extends Notifier<MidiSongPracticeState> {
  MidiSongPracticeNotifier(this.entry);

  final SongLabEntry entry;
  late MidiSongPlayer _player;
  bool _useBackingTransport = false;

  MidiSongData? _song;
  MidiSongMeta? _meta;
  FutureOr<void> Function(SongLabEntry)? _onPersist;
  Timer? _debounce;
  int _loadId = 0;
  int _operationId = 0;
  int? _loadedBpm;
  bool _disposed = false;

  bool get usesBackingTransport => _useBackingTransport;

  @override
  MidiSongPracticeState build() {
    _useBackingTransport = ref.watch(useBackingTransportProvider);
    if (!_useBackingTransport) {
      _player = ref.watch(midiSongPlayerProvider(entry));
    } else {
      ref.listen(backingTransportProvider, (previous, next) {
        state = state.copyWith(
          playing: next.playingId != null,
          loading: next.rendering,
        );
      });
    }
    ref.listen<bool>(metronomeProvider.select((s) => s.isPlaying), (
      _,
      playing,
    ) {
      if (!_useBackingTransport) {
        unawaited(playing ? start() : stop());
      } else if (playing) {
        // Pad launches queue their command before this fallback runs.
        unawaited(
          Future<void>.microtask(() async {
            if (!_disposed) await start();
          }),
        );
      }
    });
    ref.listen<int>(metronomeProvider.select((s) => s.bpm), (_, _) {
      if (_useBackingTransport ||
          ref.read(metronomeProvider).isPlaying ||
          _song == null) {
        return;
      }
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        unawaited(_reload());
      });
    });
    ref.onDispose(() {
      _disposed = true;
      ++_operationId;
      _debounce?.cancel();
      if (!_useBackingTransport) unawaited(_disposePlayer());
    });
    return const MidiSongPracticeState();
  }

  /// The UI may persist the updated entry; this provider performs no writes.
  Future<void> loadEntry({
    FutureOr<void> Function(SongLabEntry)? onPersist,
  }) async {
    _onPersist = onPersist;
    _debounce?.cancel();
    final loadId = ++_loadId;
    ++_operationId;
    _loadedBpm = null;
    _song = null;
    state = const MidiSongPracticeState(loading: true);
    try {
      if (!_useBackingTransport) await _player.stop();
      if (!_currentLoad(loadId)) return;
      final song = await ref.read(midiSongProvider(entry).future);
      if (!_currentLoad(loadId)) return;
      if (song == null) throw StateError('No MIDI song file available');
      _song = song;
      _meta = buildMidiSongMeta(
        song,
        fileUrl: entry.midiSong?.fileUrl,
        previous: entry.midiSong,
      );
      if (_useBackingTransport && entry.midiSong != null) {
        _meta = entry.midiSong!.copyWith(
          ppq: song.ppq,
          initialBpm: song.initialBpm,
          tracks: _meta!.tracks,
        );
      }
      state = state.copyWith(tracks: _meta!.tracks);
      await _reload();
    } catch (error) {
      if (_currentLoad(loadId)) await _fail(error);
    }
  }

  /// Track controls use positions in [MidiSongPracticeState.tracks], like the player.
  void setMute(int index, {required bool mute}) {
    _updateTrack(index, (track) => track.copyWith(mute: mute));
  }

  void setVolume(int index, double volume) {
    if (!volume.isFinite) {
      state = state.copyWith(error: 'Volume must be finite');
      return;
    }
    _updateTrack(
      index,
      (track) => track.copyWith(volume: volume.clamp(0.0, 1.0)),
    );
  }

  void toggleSolo(int index) {
    if (index < 0 || index >= state.tracks.length) return;
    final soloed = {...state.soloed};
    if (!soloed.remove(index)) soloed.add(index);
    state = state.copyWith(soloed: soloed);
    _syncGains();
  }

  void _updateTrack(int index, MidiTrackMeta Function(MidiTrackMeta) update) {
    if (index < 0 || index >= state.tracks.length) return;
    state = state.copyWith(
      tracks: [
        for (var i = 0; i < state.tracks.length; i++)
          if (i == index) update(state.tracks[i]) else state.tracks[i],
      ],
    );
    _syncGains();
    _meta = _meta!.copyWith(tracks: state.tracks);
    unawaited(_persist(entry.copyWith(midiSong: _meta)));
  }

  Future<void> _persist(SongLabEntry updated) async {
    try {
      await _onPersist?.call(updated);
    } catch (error) {
      if (!_disposed) state = state.copyWith(error: error.toString());
    }
  }

  void _syncGains() {
    if (_useBackingTransport) {
      // Per-track stems: mute, solo and volume are live gains, no re-render.
      final transport = ref.read(backingTransportProvider.notifier);
      final gains = state.gains;
      for (var i = 0; i < state.tracks.length; i++) {
        transport.setStemVolume(state.tracks[i].name, gains[i]);
      }
      return;
    }
    try {
      // Player indices are compact buffer positions, not MIDI or UI indices.
      final gains = state.gains;
      var bufferIndex = 0;
      for (var i = 0; i < state.tracks.length; i++) {
        if (state.skippedTracks.contains(i)) continue;
        _player.setTrackGain(bufferIndex++, gains[i]);
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> start() async {
    if (_useBackingTransport) {
      final transport = ref.read(backingTransportProvider);
      if (_song == null ||
          transport.rendering ||
          transport.playingId != null ||
          transport.queuedId != null ||
          transport.spans.isEmpty) {
        return;
      }
      try {
        await ref
            .read(backingTransportProvider.notifier)
            .launch(transport.spans.first.sectionId);
      } catch (error) {
        if (!_disposed) state = state.copyWith(error: error.toString());
      }
      return;
    }
    if (_song == null || state.playing) return;
    _debounce?.cancel();
    if (state.loading || _loadedBpm != ref.read(metronomeProvider).bpm) {
      await _reload();
      return;
    }
    final operationId = ++_operationId;
    try {
      await _player.start();
      if (_current(operationId)) state = state.copyWith(playing: true);
    } catch (error) {
      if (_current(operationId)) await _fail(error);
    }
  }

  Future<void> stop() async {
    if (_useBackingTransport) {
      await ref.read(backingTransportProvider.notifier).stop();
      return;
    }
    ++_operationId;
    _debounce?.cancel();
    state = state.copyWith(playing: false, loading: false);
    try {
      await _player.stop();
    } catch (error) {
      if (!_disposed) state = state.copyWith(error: error.toString());
    }
  }

  bool _current(int operationId) => !_disposed && operationId == _operationId;

  bool _currentLoad(int loadId) => !_disposed && loadId == _loadId;

  Future<void> _reload() async {
    final song = _song;
    if (song == null) return;
    final operationId = ++_operationId;
    final bpm = ref.read(metronomeProvider).bpm;
    _loadedBpm = null;
    state = state.copyWith(loading: true, playing: false);
    try {
      if (_useBackingTransport) {
        final transport = ref.read(backingTransportProvider);
        final resume = transport.playingId ?? transport.queuedId;
        final spans = transport.spans;
        final endTick = song.tracks.fold<int>(
          0,
          (end, track) => track.notes.fold<int>(
            end,
            (end, note) => math.max(end, note.tick + note.dur),
          ),
        );
        // Stem rendering applies per-track gains before tracks sharing a role mix.
        final meta = _meta!.copyWith(
          sectionMap: _meta!.sectionMap.isNotEmpty || spans.isEmpty
              ? _meta!.sectionMap
              : spans,
          tracks: [
            for (var i = 0; i < state.tracks.length; i++) state.tracks[i],
          ],
        );
        await ref
            .read(backingTransportProvider.notifier)
            .attach(entry.copyWith(midiSong: meta), [
              Section(
                id: 'song',
                name: 'Song',
                duration:
                    (endTick /
                            song.ppq /
                            ref.read(metronomeProvider).timeSignature.numerator)
                        .ceil(),
              ),
            ]);
        if (!_current(operationId)) return;
        state = state.copyWith(loading: false);
        if (resume != null && ref.read(metronomeProvider).isPlaying) {
          await ref.read(backingTransportProvider.notifier).launch(resume);
        }
        return;
      }
      final rendered = await compute(_renderTracks, (
        song: song,
        tracks: state.tracks,
        bpmScale: bpm / song.initialBpm,
      ));
      if (!_current(operationId)) return;
      await _player.load(rendered.buffers, sampleRate: _sampleRate);
      if (!_current(operationId)) return;
      _loadedBpm = bpm;
      state = state.copyWith(loading: false, skippedTracks: rendered.skipped);
      _syncGains();
      if (ref.read(metronomeProvider).isPlaying) await start();
    } catch (error) {
      if (_current(operationId)) await _fail(error);
    }
  }

  Future<void> _fail(Object error) async {
    state = state.copyWith(
      loading: false,
      playing: false,
      error: error.toString(),
    );
    try {
      if (!_useBackingTransport) await _player.stop();
    } catch (_) {
      // Preserve the original playback error if cleanup also fails.
    }
  }

  Future<void> _disposePlayer() async {
    try {
      await _player.stop();
    } catch (error) {
      debugPrint('[MidiSongPracticeNotifier] Stop failed: $error');
    }
    try {
      await _player.dispose();
    } catch (error) {
      debugPrint('[MidiSongPracticeNotifier] Dispose failed: $error');
    }
  }
}

final midiSongPracticeProvider = NotifierProvider.autoDispose
    .family<MidiSongPracticeNotifier, MidiSongPracticeState, SongLabEntry>(
      MidiSongPracticeNotifier.new,
    );
