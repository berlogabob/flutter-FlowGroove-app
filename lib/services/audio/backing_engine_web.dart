// ignore_for_file: web_unsafe_total

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'backing_engine.dart';
import 'backing_engine_factory.dart';
import 'backing_engine_stub.dart' show StubBackingEngine;

BackingEngine createBackingEngine({BackingWebHooks? hooks}) {
  final context = hooks?.context;
  if (hooks == null || context is! web.AudioContext) {
    return StubBackingEngine();
  }
  return WebBackingEngine(
    context: context,
    barTimeSeconds: hooks.barTimeSeconds,
    bpm: hooks.bpm,
  );
}

/// Pass the click engine's context and the click client's barTimeSeconds.
/// This engine never creates or closes an AudioContext.
class WebBackingEngine extends WebBackingScheduler {
  WebBackingEngine({
    required web.AudioContext context,
    required double Function(int) barTimeSeconds,
    required double Function() bpm,
  }) : super(
         clock: _WebBackingClock(context, barTimeSeconds, bpm),
         sources: _WebBackingSources(context),
       );
}

class _WebBackingClock implements BackingClock {
  _WebBackingClock(this.context, this._barTimeSeconds, this._bpm);

  final web.AudioContext context;
  final double Function() _bpm;

  final double Function(int) _barTimeSeconds;

  @override
  double barTimeSeconds(int bar) => _barTimeSeconds(bar);

  @override
  double get currentTime => context.currentTime;

  @override
  double get bpm => _bpm();
}

class _WebBackingSources implements BackingSourceFactory {
  _WebBackingSources(this.context);

  final web.AudioContext context;
  final _buffers = <web.AudioBuffer>[];
  final _gains = <web.GainNode>[];

  @override
  int get sampleRate => context.sampleRate.round();

  @override
  void load(BackingStems stems) {
    for (final pcm in stems.stems) {
      final buffer = context.createBuffer(1, pcm.length, stems.sampleRate);
      final samples = Float32List(pcm.length);
      for (var i = 0; i < pcm.length; i++) {
        samples[i] = pcm[i] / 32768;
      }
      buffer.copyToChannel(samples.toJS, 0);
      _buffers.add(buffer);
      final gain = context.createGain()..connect(context.destination);
      _gains.add(gain);
    }
  }

  @override
  BackingSource start(int stem, double atTime, double offset, double duration) {
    final source = context.createBufferSource()
      ..buffer = _buffers[stem]
      ..connect(_gains[stem])
      ..start(atTime, offset, duration);
    return _WebBackingSource(source);
  }

  @override
  void setGain(int stem, double gain) {
    final param = _gains[stem].gain;
    final now = context.currentTime;
    param
      ..cancelAndHoldAtTime(now)
      ..linearRampToValueAtTime(gain, now + 0.005);
  }

  @override
  void clear() {
    for (final gain in _gains) {
      gain.disconnect();
    }
    _gains.clear();
    _buffers.clear();
  }
}

class _WebBackingSource implements BackingSource {
  _WebBackingSource(this.source);

  final web.AudioBufferSourceNode source;

  @override
  void stop(double atTime) => source.stop(atTime);
}
