/// On-device song analysis for the practice-regions auto slicer: transient
/// onsets (MPC-style chop) and a tempo grid suggestion (BPM + first downbeat).
/// Pure Dart over mono PCM; run on the decoded song the screen already holds.
library;

import 'dart:math';
import 'dart:typed_data';

/// Analysis block in samples (~11.6 ms at 22.05 kHz, ~5.8 ms at 44.1 kHz).
const _hop = 256;

/// Onset strength per [_hop] block: positive change in log energy.
List<double> onsetEnvelope(Int16List pcm) {
  final n = pcm.length ~/ _hop;
  final env = List<double>.filled(n, 0);
  var prev = 0.0;
  for (var i = 0; i < n; i++) {
    var energy = 0.0;
    for (var j = i * _hop; j < (i + 1) * _hop; j++) {
      energy += pcm[j] * pcm[j];
    }
    final level = log(1 + energy / _hop);
    if (i > 0) env[i] = max(0, level - prev);
    prev = level;
  }
  return env;
}

double _blockMs(num block, int sampleRate) =>
    (block * _hop + _hop / 2) * 1000 / sampleRate;

/// Onset times in ms: local envelope peaks above mean + [sensitivity] × σ,
/// at least [minGapMs] apart. Higher sensitivity = fewer, stronger hits.
List<int> detectOnsets(
  Int16List pcm,
  int sampleRate, {
  double sensitivity = 1.5,
  int minGapMs = 80,
}) {
  final env = onsetEnvelope(pcm);
  if (env.length < 3) return const [];
  final mean = env.reduce((a, b) => a + b) / env.length;
  final sd = sqrt(
    env.map((e) => (e - mean) * (e - mean)).reduce((a, b) => a + b) /
        env.length,
  );
  final threshold = mean + sensitivity * sd;
  final onsets = <int>[];
  for (var i = 1; i < env.length - 1; i++) {
    if (env[i] <= threshold || env[i] < env[i - 1] || env[i] < env[i + 1]) {
      continue;
    }
    final ms = _blockMs(i, sampleRate).round();
    if (onsets.isEmpty || ms - onsets.last >= minGapMs) onsets.add(ms);
  }
  return onsets;
}

/// Tempo grid suggestion, 4/4 assumed. BPM from the envelope's
/// autocorrelation in 70–180 BPM (beat + half-bar + bar lags), refined
/// ±1 BPM on a beat comb; beat phase from that envelope, downbeat from a
/// low-band comb (full-band fallback when nearly flat). Null for
/// clips under 4 s. [hintBpm] (the song's BPM) picks the octave: the
/// detector can't tell 85 from 170, the song page usually can.
/// ponytail: one global tempo; songs that drift need the manual grid.
({double bpm, int firstDownbeatMs})? estimateGrid(
  Int16List pcm,
  int sampleRate, {
  double? hintBpm,
}) {
  if (pcm.length < sampleRate * 4) return null;
  final env = onsetEnvelope(pcm);
  final mean = env.reduce((a, b) => a + b) / env.length;
  final x = [for (final e in env) e - mean];

  double ac(int lag) {
    if (lag >= x.length) return 0;
    var s = 0.0;
    for (var j = lag; j < x.length; j++) {
      s += x[j] * x[j - lag];
    }
    return s;
  }

  double lagOf(double bpm) => 60 * sampleRate / (bpm * _hop);
  // A beat echoes at 2 and 4 beats (half bar, bar in 4/4); a 3:2 or 2:3
  // ghost tempo doesn't, so the sum picks the real beat, not a polyrhythm.
  var coarse = 70.0, bestScore = double.negativeInfinity;
  for (var bpm = 70.0; bpm <= 180; bpm += 0.5) {
    final lag = lagOf(bpm);
    final score =
        ac(lag.round()) + ac((2 * lag).round()) + ac((4 * lag).round());
    if (score > bestScore) (bestScore, coarse) = (score, bpm);
  }
  // Mean envelope on a beat comb; averaging over the whole song makes a
  // fine BPM search far more precise than the autocorrelation lag alone.
  double comb(double start, double step, {List<double>? envelope}) {
    final values = envelope ?? env;
    var s = 0.0;
    var n = 0;
    for (var t = start; t.round() < values.length; t += step, n++) {
      // ±1 block: a hit can round into the neighbouring block.
      final i = t.round();
      s += max(
        values[i],
        max(
          i > 0 ? values[i - 1] : 0,
          i + 1 < values.length ? values[i + 1] : 0,
        ),
      );
    }
    return n == 0 ? 0 : s / n;
  }

  var period = lagOf(coarse), phase = 0.0, score = -1.0;
  for (var bpm = coarse - 1; bpm <= coarse + 1; bpm += 0.05) {
    final p = lagOf(bpm);
    for (var o = 0; o < p; o++) {
      final v = comb(o.toDouble(), p);
      if (v > score) (score, period, phase) = (v, p, o.toDouble());
    }
  }
  var down = phase;
  for (var k = 1; k < 4; k++) {
    final o = phase + k * period;
    if (comb(o, 4 * period) > comb(down, 4 * period)) down = o;
  }
  final lowPcm = Int16List(pcm.length);
  final alpha = 1 - exp(-2 * pi * 150 / sampleRate);
  var low = 0.0;
  for (var i = 0; i < pcm.length; i++) {
    low += alpha * (pcm[i] - low);
    lowPcm[i] = low.round();
  }
  final lowEnv = onsetEnvelope(lowPcm);
  final lowScores = [
    for (var k = 0; k < 4; k++)
      comb(phase + k * period, 4 * period, envelope: lowEnv),
  ];
  final lowMax = lowScores.reduce(max);
  final lowMean = lowScores.reduce((a, b) => a + b) / 4;
  // ponytail: assumes kick on 1; syncopated bass/kicks can still need a manual grid.
  if (lowMean > 0 && lowMax / lowMean >= 1.1) {
    down = phase + lowScores.indexOf(lowMax) * period;
  }
  var bpm = 60 * sampleRate / (period * _hop);
  // Octave only (x2, /2): x1.5 would bring back the 3:2 ghost tempo.
  if (hintBpm != null && hintBpm > 0) {
    for (final octave in [bpm * 2, bpm / 2]) {
      if ((octave - hintBpm).abs() < (bpm - hintBpm).abs() &&
          (octave - hintBpm).abs() <= hintBpm * 0.08) {
        bpm = octave;
      }
    }
  }
  return (
    bpm: (bpm * 10).round() / 10,
    firstDownbeatMs: _blockMs(down, sampleRate).round(),
  );
}
