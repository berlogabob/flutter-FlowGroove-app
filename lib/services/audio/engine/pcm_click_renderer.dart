import 'dart:math';
import 'dart:typed_data';
import '../../../models/beat_mode.dart';
import 'render_config.dart';

class PcmClickRenderer {
  PcmClickRenderer({required this.sampleRate})
      : _voiceLen = (sampleRate * 0.04).round();

  final int sampleRate;
  final int _voiceLen; // 40ms

  /// Output gain applied before clamping so a full-scale click is perceptibly
  /// loud at volume 1.0 (a bare decaying sine peaks at 1.0 only momentarily and
  /// sounds quiet). Short clicks tolerate the mild saturation this introduces.
  static const double _outputGain = 2.2;

  int frameForTick(RenderConfig c, int tickIndex) =>
      (tickIndex * 60.0 / c.bpm.clamp(1, 600) / c.safeSubdivisions * sampleRate).round();

  /// Oscillator sample at [phase] radians for the given [waveType].
  double _oscillator(String waveType, double phase) {
    switch (waveType) {
      case 'square':
        return sin(phase) >= 0 ? 1.0 : -1.0;
      case 'triangle':
        return 2.0 / pi * asin(sin(phase));
      case 'sawtooth':
        final cycles = phase / (2 * pi);
        return 2.0 * (cycles - (cycles + 0.5).floorToDouble());
      case 'sine':
      default:
        return sin(phase);
    }
  }

  // One 40ms exp-decayed click at [frequency] using [waveType], amplitude [volume].
  void _mixVoice(
    Float32List out,
    int at,
    double frequency,
    double volume,
    String waveType,
  ) {
    final start = max(0, at);
    final count = min(_voiceLen, out.length - start);
    if (count <= 0) return;
    final skip = start - at; // when click began before this chunk
    for (var i = 0; i < count; i++) {
      final k = i + skip;
      final env = k < 44 ? k / 44.0 : exp(-4.0 * (k - 44) / max(1, _voiceLen - 44));
      final phase = 2 * pi * frequency * k / sampleRate;
      final v = _oscillator(waveType, phase) * env * volume * _outputGain;
      final s = out[start + i] + v;
      out[start + i] = s.clamp(-1.0, 1.0);
    }
  }

  BeatMode _modeFor(RenderConfig c, int beat, int sub) {
    if (beat < c.beatModes.length && sub < c.beatModes[beat].length) {
      return c.beatModes[beat][sub];
    }
    return BeatMode.normal;
  }

  Float32List renderChunk({
    required RenderConfig config,
    required int startFrame,
    required int frameCount,
  }) {
    final out = Float32List(frameCount);
    final total = config.totalTicks;
    if (total <= 0) return out;
    final tickFrames = frameForTick(config, 1); // interval in frames
    if (tickFrames <= 0) return out;

    // Range of absolute tick indices whose mix position can land in this chunk.
    final firstTick = ((startFrame + config.latencyOffsetFrames - _voiceLen) / tickFrames).floor();
    final lastTick = ((startFrame + frameCount + config.latencyOffsetFrames) / tickFrames).ceil();
    for (var n = max(0, firstTick); n <= lastTick; n++) {
      final beat = (n ~/ config.safeSubdivisions) % config.safeBeats;
      final sub = n % config.safeSubdivisions;
      final mode = _modeFor(config, beat, sub);
      if (mode == BeatMode.silent) continue;
      final freq = resolveClickFrequency(
        mode: mode,
        isMainBeat: sub == 0,
        accentEnabled: config.accentEnabled,
        primaryFrequency: config.accentFrequency,
        subdivisionFrequency: config.beatFrequency,
        accentFrequency: config.accentBeatFrequency,
      );
      final mixAt = frameForTick(config, n) - config.latencyOffsetFrames - startFrame;
      if (mixAt > frameCount) continue;
      _mixVoice(out, mixAt, freq, config.volume, config.waveType);
    }
    return out;
  }
}
