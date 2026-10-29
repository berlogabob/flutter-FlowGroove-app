/// On-device song analysis for the practice-regions auto slicer: transient
/// onsets (MPC-style chop) and a tempo grid suggestion (BPM + first downbeat).
/// Pure Dart over mono PCM; run on the decoded song the screen already holds.
library;

import 'dart:math';
import 'dart:typed_data';

import '../../models/audio_region.dart';

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

/// Candidate section cuts where the song's texture changes, strongest
/// first, at least a window apart. Per bar (or 2 s without a grid):
/// loudness, low/mid/high band energy, brightness and hit density,
/// z-scored; a cut scores the distance between the window (~6 s, or
/// [windowUnits]) before and after it. Musicians phrase in 4 bars, so the strongest 4-bar phase
/// is favoured. `strength` is in standard deviations above the mean cut.
/// ponytail: texture only, no harmony (chroma); a verse→chorus change with
/// the same band density and chords can be missed, mark that one by ear.
List<({int ms, double strength})> sectionCuts(
  Int16List pcm,
  int sampleRate, {
  AudioGrid? grid,
  int? windowUnits,
}) {
  final durationMs = pcm.length * 1000 ~/ sampleRate;
  final unitMs = grid?.barMs ?? 2000.0;
  // ~6 s each side, in whole 4-bar phrases: 4 bars of a fast song is too
  // short to tell a section from a fill.
  final window =
      windowUnits ??
      (grid == null ? 4 : max(1, (6000 / unitMs / 4).ceil()) * 4);
  final startMs = grid == null
      ? 0.0
      : grid.offsetMs - (grid.offsetMs / unitMs).floor() * unitMs;
  final starts = [
    for (var t = startMs; t + unitMs <= durationMs; t += unitMs) t,
  ];
  if (starts.length < 2 * window + 1) return const [];

  // Two one-pole low-passes split the signal into <200 Hz, mid, >2.5 kHz.
  double alpha(double hz) => 1 - exp(-2 * pi * hz / sampleRate);
  final a1 = alpha(200), a2 = alpha(2500);
  final env = onsetEnvelope(pcm);
  var lp1 = 0.0, lp2 = 0.0;
  var sample = 0;
  final features = <List<double>>[];
  for (final t in starts) {
    final from = (t * sampleRate / 1000).round();
    final to = min(pcm.length, ((t + unitMs) * sampleRate / 1000).round());
    var all = 0.0, low = 0.0, mid = 0.0, high = 0.0, crossings = 0;
    for (; sample < from; sample++) {
      lp1 += a1 * (pcm[sample] - lp1);
      lp2 += a2 * (pcm[sample] - lp2);
    }
    for (var i = from; i < to; i++, sample++) {
      final s = pcm[i].toDouble();
      lp1 += a1 * (s - lp1);
      lp2 += a2 * (s - lp2);
      all += s * s;
      low += lp1 * lp1;
      mid += (lp2 - lp1) * (lp2 - lp1);
      high += (s - lp2) * (s - lp2);
      if (i > from && (s >= 0) != (pcm[i - 1] >= 0)) crossings++;
    }
    final n = max(1, to - from);
    final b0 = from ~/ 256, b1 = min(env.length, to ~/ 256);
    var hits = 0.0;
    for (var b = b0; b < b1; b++) {
      hits += env[b];
    }
    features.add([
      log(1 + all / n),
      log(1 + low / n),
      log(1 + mid / n),
      log(1 + high / n),
      crossings / n,
      hits / max(1, b1 - b0),
    ]);
  }
  for (var f = 0; f < features.first.length; f++) {
    final column = [for (final row in features) row[f]];
    final mean = column.reduce((a, b) => a + b) / column.length;
    final sd = sqrt(
      column.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
          column.length,
    );
    for (final row in features) {
      row[f] = sd == 0 ? 0 : (row[f] - mean) / sd;
    }
  }

  // novelty[k]: change at the start of unit k.
  final novelty = List<double>.filled(starts.length, 0);
  for (var k = window; k <= starts.length - window; k++) {
    var d = 0.0;
    for (var f = 0; f < features.first.length; f++) {
      var before = 0.0, after = 0.0;
      for (var j = 0; j < window; j++) {
        before += features[k - 1 - j][f];
        after += features[k + j][f];
      }
      d += pow((after - before) / window, 2);
    }
    novelty[k] = sqrt(d);
  }
  if (grid != null) {
    // Peaks only: a change's slopes are wide and would outvote its phase.
    final phaseScore = List<double>.filled(4, 0);
    for (var k = 1; k < novelty.length - 1; k++) {
      if (novelty[k] >= novelty[k - 1] && novelty[k] >= novelty[k + 1]) {
        phaseScore[k % 4] += novelty[k];
      }
    }
    final phase = phaseScore.indexOf(phaseScore.reduce(max));
    for (var k = 0; k < novelty.length; k++) {
      if (k % 4 != phase) novelty[k] *= 0.6;
    }
  }
  final scored = [
    for (var k = window; k <= starts.length - window; k++) novelty[k],
  ];
  final mean = scored.reduce((a, b) => a + b) / scored.length;
  final sd = sqrt(
    scored.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        scored.length,
  );
  final peaks = [
    for (var k = window; k <= starts.length - window; k++)
      if (novelty[k] >= novelty[k - 1] &&
          (k + 1 >= novelty.length || novelty[k] >= novelty[k + 1]))
        k,
  ]..sort((a, b) => novelty[b].compareTo(novelty[a]));
  final picked = <int>[];
  for (final k in peaks) {
    if (picked.every((p) => (p - k).abs() >= window)) picked.add(k);
  }
  return [
    for (final k in picked)
      (
        ms: starts[k].round(),
        strength: sd == 0 ? 0.0 : (novelty[k] - mean) / sd,
      ),
  ];
}

/// The [count] strongest of [cuts], in time order.
List<int> topSectionCuts(List<({int ms, double strength})> cuts, int count) =>
    [for (final cut in cuts.take(count)) cut.ms]..sort();

/// How many [cuts] to start with: one fewer than the song map's sections
/// when it has any, otherwise the clearly strong ones (half a σ up).
int suggestedSectionCuts(
  List<({int ms, double strength})> cuts, {
  int songSections = 0,
}) => songSections > 1
    ? min(songSections - 1, cuts.length)
    : cuts.where((cut) => cut.strength >= 0.5).length;
