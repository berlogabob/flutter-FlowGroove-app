import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/midi_pattern.dart';
import '../../models/section.dart';
import '../../models/section_span.dart';
import '../../models/song_lab.dart';
import '../../services/audio/backing_engine.dart';
import '../../services/audio/backing_engine_factory.dart';
import '../../services/audio/midi/backing_stem_builder.dart';
import '../../services/audio/midi/diagnostic_stem.dart';
import '../../services/audio/midi/drum_loop_renderer.dart';
import '../../services/audio/midi/drum_samples.dart';
import '../../utils/bar_math.dart';
import '../../utils/pad_state.dart';
import '../../utils/play_mode.dart';
import '../../utils/quantize.dart';
import '../metronome_runtime_providers.dart';
import 'drum_practice_provider.dart';
import 'metronome_provider.dart';
import 'midi_song_provider.dart';

final backingEngineProvider = Provider<BackingEngine>((ref) {
  BackingWebHooks? hooks;
  if (kIsWeb) {
    final client = ref.read(metronomePlaybackClientProvider);
    final audio = ref.read(metronomeAudioClientProvider);
    if (client is WebAudioLookaheadPlaybackClient &&
        audio is WebAudioMetronomeAudioClient) {
      hooks = (
        context: audio.audioContextForBacking(),
        barTimeSeconds: client.barTimeSeconds,
        bpm: () => ref.read(metronomeProvider).bpm.toDouble(),
      );
    }
  }
  final engine = createBackingEngine(hooks: hooks);
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

const _unchanged = Object();

class BackingTransportState {
  const BackingTransportState({
    this.spans = const [],
    this.playingId,
    this.queuedId,
    this.rendering = false,
    this.mode = PlayMode.loop,
    this.quantize = Quantize.bar,
    this.songBar = 0,
  });

  final List<SectionSpan> spans;
  final String? playingId;
  final String? queuedId;
  final bool rendering;
  final PlayMode mode;
  final Quantize quantize;

  bool get loop => mode == PlayMode.loop;
  final int songBar;

  PadState padState(String sectionId) => padStateFor(
    sectionId: sectionId,
    playingId: playingId,
    queuedId: queuedId,
  );

  BackingTransportState copyWith({
    List<SectionSpan>? spans,
    Object? playingId = _unchanged,
    Object? queuedId = _unchanged,
    bool? rendering,
    PlayMode? mode,
    Quantize? quantize,
    int? songBar,
  }) => BackingTransportState(
    spans: spans ?? this.spans,
    playingId: identical(playingId, _unchanged)
        ? this.playingId
        : playingId as String?,
    queuedId: identical(queuedId, _unchanged)
        ? this.queuedId
        : queuedId as String?,
    rendering: rendering ?? this.rendering,
    mode: mode ?? this.mode,
    quantize: quantize ?? this.quantize,
    songBar: songBar ?? this.songBar,
  );
}

class BackingTransportNotifier extends Notifier<BackingTransportState> {
  late BackingEngine _engine;
  SongLabEntry? _entry;
  Timer? _debounce;
  int _generation = 0;
  int _token = 0;
  int _bar = 0;
  BackingCommand? _playing;
  final _commands = <int, ({BackingCommand command, String? id})>{};
  List<String> _names = [];
  final _muted = <String>{};
  String? _solo;
  String? _resumeId;
  Future<void> _engineWork = Future.value();

  @override
  BackingTransportState build() {
    _engine = ref.read(backingEngineProvider);
    final states = _engine.states.listen(_onState);
    final bars = _engine.bars.listen((bar) {
      _bar = bar;
      final playing = _playing;
      if (state.rendering || playing == null || bar < playing.atBar) return;
      final elapsed = bar - playing.atBar;
      final songBar =
          playing.fromBar + (playing.loop ? elapsed % playing.bars : elapsed);
      // In a song run the highlighted pad follows the section being played.
      final section = _isSongRun(playing) ? _spanAt(songBar) : null;
      state = state.copyWith(
        songBar: songBar,
        playingId: section?.sectionId ?? state.playingId,
      );
    });
    ref.listen(metronomeProvider, (previous, next) {
      if (previous?.isPlaying == true && !next.isPlaying) {
        _resumeId = null;
        unawaited(stop());
        _commands.clear();
        _playing = null;
        state = state.copyWith(playingId: null, queuedId: null);
      }
      if (previous?.bpm != next.bpm && _entry != null) {
        _resumeId = state.playingId ?? state.queuedId ?? _resumeId;
        final generation = _beginRender();
        _debounce = Timer(const Duration(milliseconds: 300), () async {
          try {
            await _render(generation);
          } catch (_) {
            // Keep launches disabled until a successful attach or tempo change.
          }
        });
      }
    });
    ref.onDispose(() {
      _generation++;
      _debounce?.cancel();
      unawaited(states.cancel());
      unawaited(bars.cancel());
      unawaited(_serialize(_engine.clear));
    });
    return const BackingTransportState();
  }

  Future<void> _serialize(Future<void> Function() action) {
    final work = _engineWork.then((_) => action());
    _engineWork = work.catchError((Object _) {});
    return work;
  }

  int _beginRender() {
    _debounce?.cancel();
    _commands.clear();
    _playing = null;
    state = state.copyWith(rendering: true, playingId: null, queuedId: null);
    unawaited(_serialize(_engine.clear));
    return ++_generation;
  }

  void _clearPattern() {
    if (ref.exists(drumPracticeProvider)) {
      unawaited(ref.read(drumPracticeProvider.notifier).clearPattern());
    }
  }

  Future<void> attachPattern(MidiPattern pattern, double bpm) async {
    _entry = null;
    _resumeId = null;
    _muted.clear();
    _solo = null;
    final generation = _beginRender();
    final metro = ref.read(metronomeProvider);
    final ticks = metro.timeSignature.numerator * metro.regularBeats;
    final interval = (60000000 / metro.bpm / metro.regularBeats).round();
    final sampleRate = await _engine.engineSampleRate();
    await preloadDrumSamples();
    if (!ref.mounted || generation != _generation) return;
    final patternBars =
        pattern.bars *
        pattern.beatsPerBar *
        metro.bpm /
        (bpm * metro.timeSignature.numerator);
    final nearestBar = patternBars.round();
    final bars = (patternBars - nearestBar).abs() < 1e-9
        ? nearestBar
        : patternBars.ceil();
    final frames = barStartFrame(
      bar: bars,
      ticksPerBar: ticks,
      intervalMicros: interval.toDouble(),
      sampleRate: sampleRate,
      epochFrame: 0,
    );
    final stems = BackingStems(
      stems: [
        renderDrumLoop(pattern, bpm, sampleRate: sampleRate, frames: frames),
      ],
      names: const ['Drums'],
      sampleRate: sampleRate,
      renderBpm: metro.bpm.toDouble(),
      ticksPerBar: ticks,
      intervalMicros: interval,
    );
    await _serialize(() async {
      if (!ref.mounted || generation != _generation) return;
      await _engine.load(stems);
    });
    if (!ref.mounted || generation != _generation) return;
    _names = stems.names;
    _applyGains();
    state = state.copyWith(
      rendering: false,
      spans: [SectionSpan(sectionId: 'drum-pattern', startBar: 0, bars: bars)],
      songBar: 0,
      mode: PlayMode.loop,
    );
  }

  Future<void> attach(SongLabEntry entry, List<Section> sections) async {
    _clearPattern();
    _entry = entry;
    _resumeId = null;
    _muted.clear();
    _solo = null;
    var start = 0;
    final spans = entry.midiSong?.sectionMap;
    state = state.copyWith(
      spans: List.unmodifiable(
        spans != null && spans.isNotEmpty
            ? spans
            : sections.map((section) {
                final span = SectionSpan(
                  sectionId: section.id,
                  startBar: start,
                  bars: section.duration,
                );
                start += section.duration;
                return span;
              }),
      ),
      songBar: 0,
    );
    await _render(_beginRender());
  }

  Future<void> _render(int generation) async {
    final entry = _entry!;
    final song = await ref.read(midiSongProvider(entry).future);
    if (!ref.mounted || generation != _generation) return;
    if (song == null) throw StateError('No MIDI song attached');
    final metro = ref.read(metronomeProvider);
    final bpm = entry.midiSong?.useFileTempo == true
        ? song.initialBpm
        : metro.bpm.toDouble();
    final sampleRate = await _engine.engineSampleRate();
    final ticks = metro.timeSignature.numerator * metro.regularBeats;
    final interval = (60000000 / bpm / metro.regularBeats).round();
    final stems = await buildBackingStems(
      song: song,
      meta: entry.midiSong,
      renderBpm: bpm,
      sampleRate: sampleRate,
      ticksPerBar: ticks,
      intervalMicros: interval.toDouble(),
      perTrack: true,
    );
    if (!ref.mounted || generation != _generation) return;
    await _serialize(() async {
      if (!ref.mounted || generation != _generation) return;
      await _engine.load(
        BackingStems(
          stems: stems.values.toList(),
          names: stems.keys.toList(),
          sampleRate: sampleRate,
          renderBpm: bpm,
          ticksPerBar: ticks,
          intervalMicros: interval,
        ),
      );
    });
    if (!ref.mounted || generation != _generation) return;
    _names = stems.keys.toList();
    // Per-track stems keep muted tracks; mute is applied live from the saved flags.
    // Seed once per song: later reloads (tempo) keep the live mute state.
    if (_seededEntryId != entry.id) {
      _seededEntryId = entry.id;
      _muted
        ..clear()
        ..addAll([
          for (final track in entry.midiSong!.tracks)
            if (track.mute && _names.contains(track.name)) track.name,
        ]);
    }
    _applyGains();
    state = state.copyWith(rendering: false);
    final resume = _resumeId;
    _resumeId = null;
    if (resume != null && ref.read(metronomeProvider).isPlaying) {
      await _launch(resume, _nextBar(Quantize.bar));
    }
  }

  SectionSpan? _spanAt(int songBar) {
    for (final span in state.spans) {
      if (songBar >= span.startBar && songBar < span.startBar + span.bars) {
        return span;
      }
    }
    return null;
  }

  /// A one-shot launch that runs past its own section into the following ones.
  bool _isSongRun(BackingCommand command) {
    if (command.loop) return false;
    final start = _spanAt(command.fromBar);
    return start != null && command.bars > start.bars;
  }

  int get _songBars => state.spans.fold<int>(
    0,
    (end, span) => math.max(end, span.startBar + span.bars),
  );

  /// Transport bar where the section that is playing ends, so the next block
  /// starts exactly after it. Falls back to the next bar when nothing is playing.
  int _blockBoundaryBar() {
    final next = _nextBar(Quantize.bar);
    final playing = _playing;
    if (playing == null || state.playingId == null) return next;
    final elapsed = _bar - playing.atBar;
    if (elapsed < 0) return next;
    final int remaining;
    if (playing.loop) {
      remaining = playing.bars - elapsed % playing.bars;
    } else {
      final span = elapsed >= playing.bars
          ? null
          : _spanAt(playing.fromBar + elapsed);
      if (span == null) return next;
      remaining = span.startBar + span.bars - (playing.fromBar + elapsed);
    }
    return math.max(next, _bar + remaining);
  }

  int _nextBar(Quantize quantize) {
    final metro = ref.read(metronomeProvider);
    final current = metro.completedBars > _bar ? metro.completedBars : _bar;
    final ticks = metro.timeSignature.numerator * metro.regularBeats;
    // Commands use whole bars; round beat/now boundaries up to an engine bar.
    final frame = barStartFrame(
      bar: current,
      ticksPerBar: ticks,
      intervalMicros: 1000000,
      sampleRate: 1,
      epochFrame: 0,
    );
    final boundary = nextBoundaryFrame(
      nowFrame: frame,
      q: quantize,
      tickFrames: 1,
      ticksPerBeat: metro.regularBeats,
      ticksPerBar: ticks,
      leadFrames: 1,
    );
    return (boundary / ticks).ceil();
  }

  Future<void> launchDiagnostic() async {
    const bars = 4;
    const id = 'sync-test';
    _clearPattern();
    _entry = null;
    _resumeId = null;
    _muted.clear();
    _solo = null;
    final generation = _beginRender();
    final metro = ref.read(metronomeProvider);
    final sampleRate = await _engine.engineSampleRate();
    final stems = diagnosticStems(
      sampleRate: sampleRate,
      intervalMicros: (60000000 / metro.bpm / metro.regularBeats).round(),
      ticksPerBar: metro.timeSignature.numerator * metro.regularBeats,
      renderBpm: metro.bpm.toDouble(),
      bars: bars,
    );
    await _serialize(() async {
      if (!ref.mounted || generation != _generation) return;
      await _engine.load(stems);
    });
    if (!ref.mounted || generation != _generation) return;
    _names = stems.names;
    _applyGains();
    state = state.copyWith(
      rendering: false,
      spans: const [SectionSpan(sectionId: id, startBar: 0, bars: bars)],
      songBar: 0,
      mode: PlayMode.loop,
    );
    await launch(id);
  }

  Future<void> launch(String sectionId) async {
    if (state.rendering) return;
    final metro = ref.read(metronomeProvider);
    if (!state.spans.any(
      (span) => span.sectionId == sectionId && span.bars > 0,
    )) {
      return;
    }
    if (!metro.isPlaying) {
      _bar = 0;
      ref.read(metronomeProvider.notifier).start();
      await _launch(sectionId, metro.countInBars);
    } else {
      await _launch(
        sectionId,
        state.quantize == Quantize.block
            ? _blockBoundaryBar()
            : _nextBar(state.quantize),
      );
    }
  }

  Future<void> _launch(String sectionId, int atBar) async {
    final span = state.spans.firstWhere((span) => span.sectionId == sectionId);
    final command = BackingCommand(
      token: ++_token,
      kind: BackingKind.launch,
      fromBar: span.startBar,
      // Song mode runs from this section to the end of the song, once.
      bars: state.mode == PlayMode.song
          ? math.max(span.bars, _songBars - span.startBar)
          : span.bars,
      loop: state.mode == PlayMode.loop,
      atBar: atBar,
    );
    _commands[command.token] = (command: command, id: sectionId);
    state = state.copyWith(queuedId: sectionId);
    await _engine.command(command);
  }

  void _onState(BackingState event) {
    if (state.rendering) return;
    final pending = _commands[event.token];
    if (pending == null) return;
    switch (event.kind) {
      case BackingStateKind.queued:
        if (event.token == _token) state = state.copyWith(queuedId: pending.id);
      case BackingStateKind.playing:
        _commands.removeWhere((token, _) => token < event.token);
        _playing = pending.command;
        state = state.copyWith(
          playingId: pending.id,
          queuedId: event.token == _token ? null : state.queuedId,
          songBar: pending.command.fromBar,
        );
      case BackingStateKind.stopped:
        if (_playing?.token == event.token ||
            pending.command.kind == BackingKind.stop) {
          _commands.removeWhere((token, _) => token <= event.token);
          _playing = null;
          state = state.copyWith(
            playingId: null,
            queuedId: event.token == _token ? null : state.queuedId,
          );
        }
    }
  }

  Future<void> stop({bool atBar = false}) async {
    _resumeId = null;
    if (state.rendering) return;
    final command = BackingCommand(
      token: ++_token,
      kind: BackingKind.stop,
      atBar: atBar ? _nextBar(Quantize.bar) : _bar,
    );
    _commands[command.token] = (command: command, id: null);
    state = state.copyWith(queuedId: null);
    await _engine.command(command);
  }

  void setMode(PlayMode mode) => state = state.copyWith(mode: mode);
  void setQuantize(Quantize quantize) =>
      state = state.copyWith(quantize: quantize);

  String? _seededEntryId;

  void muteStem(String role, {bool mute = true}) {
    mute ? _muted.add(role) : _muted.remove(role);
    if (!state.rendering) _applyGains();
  }

  void soloStem(String role, {bool solo = true}) {
    _solo = solo ? role : null;
    if (!state.rendering) _applyGains();
  }

  void minusOne(String role) => muteStem(role);

  void _applyGains() {
    for (var i = 0; i < _names.length; i++) {
      final name = _names[i];
      _engine.setGain(
        i,
        _muted.contains(name) || (_solo != null && _solo != name) ? 0 : 1,
      );
    }
  }
}

final backingTransportProvider =
    NotifierProvider<BackingTransportNotifier, BackingTransportState>(
      BackingTransportNotifier.new,
    );
