import 'dart:math';
import 'dart:typed_data';

import '../../../utils/bar_math.dart';

/// Mono, additive backing playback on the engine's absolute frame grid.
class BackingMixer {
  BackingMixer(this.sampleRate) {
    if (sampleRate <= 0) throw ArgumentError.value(sampleRate, 'sampleRate');
  }

  final int sampleRate;
  void Function(String token, String state, int transportBar)? onState;

  /// Set before a stopped callback; `epoch` means the engine grid changed.
  String? stopReason;

  Map<String, Int16List> _stems = {};
  final Map<String, _Gain> _gains = {};
  final List<_Command> _commands = [];
  _Command? _playing;
  double _renderBpm = 0;
  double _renderInterval = 0;
  int _renderTicks = 0;
  int? _epoch;
  double? _interval;
  int? _nextFrame;

  void load({
    required Map<String, Int16List> stems,
    required double renderBpm,
    required int ticksPerBar,
    required double intervalMicros,
  }) {
    _validateGrid(ticksPerBar, intervalMicros);
    if (!renderBpm.isFinite || renderBpm <= 0) {
      throw ArgumentError.value(renderBpm, 'renderBpm');
    }
    _stems = Map.of(stems);
    _gains
      ..clear()
      ..addEntries(stems.keys.map((key) => MapEntry(key, _Gain())));
    _renderBpm = renderBpm;
    _renderTicks = ticksPerBar;
    _renderInterval = intervalMicros;
    _commands.clear();
    _playing = null;
    _epoch = null;
    _interval = null;
    _nextFrame = null;
    stopReason = null;
  }

  /// Commands sharing a bar take effect in submission order.
  /// Queued callbacks identify the command's scheduled transport bar.
  void command({
    required String token,
    required String kind,
    required int fromBar,
    required int bars,
    required bool loop,
    required int atBar,
  }) {
    if (kind != 'launch' && kind != 'stop') {
      throw ArgumentError.value(kind, 'kind');
    }
    if (atBar < 0 || (kind == 'launch' && (fromBar < 0 || bars <= 0))) {
      throw ArgumentError('Invalid backing bar range');
    }
    final command = _Command(token, kind, fromBar, bars, atBar, loop: loop);
    final index = _commands.indexWhere((other) => other.atBar > atBar);
    _commands.insert(index < 0 ? _commands.length : index, command);
    onState?.call(token, 'queued', atBar);
  }

  void setGain(String stem, double gain) {
    final envelope = _gains[stem];
    if (envelope == null) throw ArgumentError.value(stem, 'stem');
    if (!gain.isFinite) throw ArgumentError.value(gain, 'gain');
    envelope
      ..target = gain
      ..remaining = max(1, (sampleRate * 0.005).round());
  }

  void mix({
    required Float32List out,
    required int chunkStart,
    required double engineBpm,
    required int epochFrame,
    required int ticksPerBar,
    required double intervalMicros,
  }) {
    _validateGrid(ticksPerBar, intervalMicros);
    int start(int bar) => barStartFrame(
      bar: bar,
      ticksPerBar: ticksPerBar,
      intervalMicros: intervalMicros,
      sampleRate: sampleRate,
      epochFrame: epochFrame,
    );
    int barAt(int frame) {
      var bar =
          ((frame - epochFrame) /
                  (ticksPerBar *
                      tickIntervalFrames(intervalMicros, sampleRate)))
              .floor();
      while (start(bar) > frame) {
        bar--;
      }
      while (start(bar + 1) <= frame) {
        bar++;
      }
      return bar;
    }

    if (_epoch != null &&
        (_epoch != epochFrame || _interval != intervalMicros)) {
      final cancelled = [?_playing, ..._commands];
      _playing = null;
      _commands.clear();
      for (final command in cancelled) {
        _stopped(command.token, barAt(chunkStart), 'epoch');
      }
    }
    _epoch = epochFrame;
    _interval = intervalMicros;
    final skipped = max(0, chunkStart - (_nextFrame ?? chunkStart));
    for (final gain in _gains.values) {
      gain.advance(skipped);
    }
    final audible =
        (_renderBpm - engineBpm).abs() < 0.001 &&
        _renderInterval == intervalMicros;
    var offset = 0;
    while (offset < out.length) {
      final frame = chunkStart + offset;
      final bar = barAt(frame);
      _advance(bar);
      final count = min(out.length - offset, start(bar + 1) - frame);
      final playing = _playing;
      if (audible && playing != null) {
        final elapsed = bar - playing.atBar;
        final songBar =
            playing.fromBar + (playing.loop ? elapsed % playing.bars : elapsed);
        int songStart(int b) => barStartFrame(
          bar: b,
          ticksPerBar: _renderTicks,
          intervalMicros: _renderInterval,
          sampleRate: sampleRate,
          epochFrame: 0,
        );
        final sourceStart = songStart(songBar);
        final sourceEnd = songStart(songBar + 1);
        final source = sourceStart + frame - start(bar);
        for (final entry in _stems.entries) {
          final gain = _gains[entry.key]!;
          for (var i = 0; i < count; i++) {
            final sample = source + i;
            if (sample >= sourceStart &&
                sample < sourceEnd &&
                sample < entry.value.length) {
              out[offset + i] += entry.value[sample] * gain.at(i) / 32768.0;
            }
          }
        }
      }
      for (final gain in _gains.values) {
        gain.advance(count);
      }
      offset += count;
    }
    _nextFrame = chunkStart + out.length;
  }

  void _advance(int bar) {
    while (_commands.isNotEmpty && _commands.first.atBar <= bar) {
      final command = _commands.removeAt(0);
      _finish(command.atBar);
      if (command.kind == 'stop') {
        _playing = null;
        _stopped(command.token, command.atBar, 'command');
      } else {
        _playing = command;
        stopReason = null;
        onState?.call(command.token, 'playing', command.atBar);
      }
    }
    _finish(bar);
  }

  void _finish(int bar) {
    final playing = _playing;
    if (playing != null &&
        !playing.loop &&
        bar >= playing.atBar + playing.bars) {
      _playing = null;
      _stopped(playing.token, playing.atBar + playing.bars, 'ended');
    }
  }

  void _stopped(String token, int bar, String reason) {
    stopReason = reason;
    onState?.call(token, 'stopped', bar);
  }

  void _validateGrid(int ticks, double interval) {
    if (ticks <= 0 ||
        !interval.isFinite ||
        interval <= 0 ||
        ticks * tickIntervalFrames(interval, sampleRate) < 1) {
      throw ArgumentError('Invalid backing grid');
    }
  }
}

class _Command {
  _Command(
    this.token,
    this.kind,
    this.fromBar,
    this.bars,
    this.atBar, {
    required this.loop,
  });

  final String token;
  final String kind;
  final int fromBar;
  final int bars;
  final bool loop;
  final int atBar;
}

class _Gain {
  double value = 1;
  double target = 1;
  int remaining = 0;

  // The first frame retains the current gain; the target is reached at 5 ms.
  double at(int offset) => remaining == 0 || offset >= remaining
      ? target
      : value + (target - value) * offset / remaining;

  void advance(int frames) {
    value = at(frames);
    remaining = max(0, remaining - frames);
  }
}
