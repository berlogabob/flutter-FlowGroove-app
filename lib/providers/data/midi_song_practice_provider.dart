import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/midi_song.dart';
import '../../models/song_lab.dart';
import '../../services/audio/midi/midi_song_meta_builder.dart';
import '../../services/audio/midi/midi_song_player.dart';
import '../../services/audio/midi/midi_track_renderer.dart';
import 'metronome_provider.dart';
import 'midi_song_provider.dart';

class MidiSongPracticeState {
  const MidiSongPracticeState({
    this.loading = false,
    this.error,
    this.tracks = const [],
    this.playing = false,
    this.soloed = const {},
  });

  final bool loading;
  final String? error;
  final List<MidiTrackMeta> tracks;
  final bool playing;
  final Set<int> soloed;

  MidiSongPracticeState copyWith({
    bool? loading,
    String? error,
    List<MidiTrackMeta>? tracks,
    bool? playing,
    Set<int>? soloed,
  }) => MidiSongPracticeState(
    loading: loading ?? this.loading,
    error: error,
    tracks: tracks == null ? this.tracks : List.unmodifiable(tracks),
    playing: playing ?? this.playing,
    soloed: soloed == null ? this.soloed : Set.unmodifiable(soloed),
  );
}

final midiSongPlayerProvider = Provider.autoDispose
    .family<MidiSongPlayer, SongLabEntry>(
      (ref, entry) => createMidiSongPlayer(),
    );

typedef _RenderRequest = ({
  MidiSongData song,
  List<MidiTrackMeta> tracks,
  double bpmScale,
});

List<Int16List> _renderTracks(_RenderRequest request) => [
  for (var i = 0; i < request.song.tracks.length; i++)
    renderMidiTrack(
      song: request.song,
      track: request.song.tracks[i],
      role: request.tracks[i].effectiveRole,
      bpmScale: request.bpmScale,
    ),
];

class MidiSongPracticeNotifier extends Notifier<MidiSongPracticeState> {
  MidiSongPracticeNotifier(this.entry);

  final SongLabEntry entry;
  late MidiSongPlayer _player;
  MidiSongData? _song;
  MidiSongMeta? _meta;
  FutureOr<void> Function(SongLabEntry)? _onPersist;
  Timer? _debounce;
  int _loadId = 0;
  int _operationId = 0;
  int? _loadedBpm;
  bool _disposed = false;

  @override
  MidiSongPracticeState build() {
    _player = ref.watch(midiSongPlayerProvider(entry));
    ref.listen<bool>(metronomeProvider.select((s) => s.isPlaying), (
      _,
      playing,
    ) {
      unawaited(playing ? start() : stop());
    });
    ref.listen<int>(metronomeProvider.select((s) => s.bpm), (_, _) {
      if (ref.read(metronomeProvider).isPlaying || _song == null) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        unawaited(_reload());
      });
    });
    ref.onDispose(() {
      _disposed = true;
      ++_operationId;
      _debounce?.cancel();
      unawaited(_disposePlayer());
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
      await _player.stop();
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
    try {
      // Player indices are buffer positions, whereas MIDI indices may be sparse.
      for (var i = 0; i < state.tracks.length; i++) {
        final track = state.tracks[i];
        final audible =
            !track.mute && (state.soloed.isEmpty || state.soloed.contains(i));
        _player.setTrackGain(i, audible ? track.volume : 0);
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> start() async {
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
      final buffers = await compute(_renderTracks, (
        song: song,
        tracks: state.tracks,
        bpmScale: bpm / song.initialBpm,
      ));
      if (!_current(operationId)) return;
      await _player.load(buffers);
      if (!_current(operationId)) return;
      _loadedBpm = bpm;
      state = state.copyWith(loading: false);
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
      await _player.stop();
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
