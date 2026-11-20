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

double snapBpm(double bpm) => (bpm - bpm.round()).abs() <= 0.05
    ? bpm.roundToDouble()
    : (bpm * 10).round() / 10;

/// Tempo grid suggestion, 4/4 assumed. Without a hint, Lua's weighted
/// autocorrelation searches 60–200 BPM. With [hintBpm] (the song's BPM),
/// beat, half-bar and bar lags estimate the pulse and the hint picks its
/// octave. A beat comb refines tempo and phase, and a trusted first kick
/// anchors the downbeat (low-band comb fallback). Null for clips under 4 s.
/// ponytail: one global tempo; songs that drift need the manual grid.
({double bpm, int firstDownbeatMs})? estimateGrid(
  Int16List pcm,
  int sampleRate, {
  double? hintBpm,
}) {
  if (pcm.length < sampleRate * 4) return null;
  final env = onsetEnvelope(pcm);
  if (env.isEmpty) return null;
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
  double bpmAtLag(int lag) => 60 * sampleRate / (lag * _hop);
  final hasHint = hintBpm != null && hintBpm > 0;
  var coarse = 70.0;
  var refineRadius = 1.0;
  var bestScore = double.negativeInfinity;
  if (hasHint) {
    // Preserve the beat, half-bar and bar search used with song BPM hints.
    for (var bpm = 70.0; bpm <= 180; bpm += 0.5) {
      final lag = lagOf(bpm);
      final score =
          ac(lag.round()) + ac((2 * lag).round()) + ac((4 * lag).round());
      if (score > bestScore) (bestScore, coarse) = (score, bpm);
    }
  } else {
    final minLag = max(1, lagOf(200).ceil());
    final maxLag = lagOf(60).floor();
    if (maxLag <= minLag || x.length < 2 * maxLag) return null;
    var bestLag = minLag;
    var spread = 0.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      final correlation = ac(lag) / (x.length - lag);
      spread += correlation.abs();
      final distance = log(bpmAtLag(lag) / 120) / ln2 / 0.9;
      final score = correlation * exp(-0.5 * distance * distance);
      if (score > bestScore) (bestScore, bestLag) = (score, lag);
    }
    if (spread == 0) return null;
    coarse = bpmAtLag(bestLag);
    // A single bucket of lag can span several BPM at fast tempos.
    refineRadius = max(refineRadius, bpmAtLag(max(1, bestLag - 1)) - coarse);
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

  ({double period, double phase}) refine(double center, {double radius = 1}) {
    var period = lagOf(center);
    var phase = 0.0;
    var score = -1.0;
    for (var step = 0; step <= 2 * radius / 0.05; step++) {
      final p = lagOf(center - radius + step * 0.05);
      for (var o = 0; o < p; o++) {
        final v = comb(o.toDouble(), p);
        if (v > score) (score, period, phase) = (v, p, o.toDouble());
      }
    }
    return (period: period, phase: phase);
  }

  var refined = refine(coarse, radius: refineRadius);
  final measured = 60 * sampleRate / (refined.period * _hop);
  final metered = meterBpm(env, sampleRate / _hop, measured);
  if (metered != measured) refined = refine(metered);
  var period = refined.period;
  var phase = refined.phase;
  var bpm = 60 * sampleRate / (period * _hop);
  // Keep octave hints on the final meter before choosing the downbeat.
  if (hasHint) {
    for (final octave in [bpm * 2, bpm / 2]) {
      if ((octave - hintBpm).abs() < (bpm - hintBpm).abs() &&
          (octave - hintBpm).abs() <= hintBpm * 0.08) {
        bpm = octave;
      }
    }
    period = lagOf(bpm);
    phase %= period;
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
  final kick = firstKickSeconds(pcm, sampleRate);
  final phaseSeconds = phase * _hop / sampleRate;
  final beatSeconds = period * _hop / sampleRate;
  final k = kickDownbeatIndex(
    kick,
    phaseSeconds,
    beatSeconds,
    ((down - phase) / period).round(),
  );
  down = phase + k * period;
  return (
    bpm: snapBpm(bpm),
    firstDownbeatMs: _blockMs(down, sampleRate).round(),
  );
}

/// Lua's beat + bar meter comparison, interpolating fractional AC lags.
double meterBpm(List<double> strength, double rate, double bpm) {
  final n = strength.length;
  if (rate <= 0 || bpm <= 0 || n <= (4 * rate * 60 / (bpm * 3 / 4)).ceil()) {
    return bpm;
  }
  final mean = strength.reduce((a, b) => a + b) / n;
  double at(int k) {
    var sum = 0.0;
    for (var i = 0; i < n - k; i++) {
      sum += (strength[i] - mean) * (strength[i + k] - mean);
    }
    return sum / (n - k);
  }

  double ac(double lag) {
    final k = lag.floor();
    final fraction = lag - lag.floor();
    return at(k) * (1 - fraction) + at(k + 1) * fraction;
  }

  double score(double candidate) {
    final beat = rate * 60 / candidate;
    return ac(beat) + ac(4 * beat);
  }

  return score(bpm * 3 / 4) > score(bpm) ? bpm * 3 / 4 : bpm;
}

/// Only an on-beat first kick may override the full-song downbeat comb.
int kickDownbeatIndex(double? kick, double phase, double period, int comb) {
  if (kick == null) return comb;
  final beats = (kick - phase) / period;
  final beat = (beats + 0.5).floor();
  return (beats - beat).abs() <= 0.25 ? beat % 4 : comb;
}

/// First low-band drum entry, using kick.lua's cascaded 110 Hz biquads and
/// 10 ms energy buckets. Null for silence; callers gate against the beat phase.
double? firstKickSeconds(Int16List pcm, int sampleRate) {
  if (sampleRate <= 220 || pcm.isEmpty) return null;
  final w = 2 * pi * 110 / sampleRate;
  final c = cos(w);
  final alpha = sin(w) / (2 * 0.70710678);
  final a0 = 1 + alpha;
  final b0 = (1 - c) / (2 * a0);
  final b1 = (1 - c) / a0;
  final a1 = -2 * c / a0;
  final a2 = (1 - alpha) / a0;
  double z1 = 0;
  double z2 = 0;
  double z3 = 0;
  double z4 = 0;
  double sum = 0;
  var bucket = 0;
  var count = 0;
  final low = <double>[];
  for (var i = 0; i < pcm.length; i++) {
    final next = i * 100 ~/ sampleRate;
    if (next != bucket) {
      low.add(sum / count);
      bucket = next;
      sum = 0;
      count = 0;
    }
    final x = pcm[i] / 32768;
    final y = b0 * x + z1;
    z1 = b1 * x - a1 * y + z2;
    z2 = b0 * x - a2 * y;
    final value = b0 * y + z3;
    z3 = b1 * y - a1 * value + z4;
    z4 = b0 * y - a2 * value;
    sum += value * value;
    count++;
  }
  if (count > 0) low.add(sum / count);
  return kickEntrySeconds(low, 100);
}

/// Pure envelope decoder, also used by the Lua reference's synthetic checks.
double? kickEntrySeconds(List<double> low, double rate) {
  if (low.isEmpty) return null;
  final energy = [for (final x in low) log(1 + 1e4 * x)];
  final onsets = [
    for (var i = 0; i < energy.length; i++)
      max(0, energy[i] - (i == 0 ? 0 : energy[i - 1])),
  ];
  final sorted = [...energy]..sort();
  if (sorted.last == 0) return null;
  final median =
      (sorted[(sorted.length - 1) ~/ 2] + sorted[sorted.length ~/ 2]) / 2;
  final window = max(1, rate.round());
  var sum = 0.0;
  var entry = -1;
  for (var i = 0; i < energy.length; i++) {
    sum += energy[i] - (i >= window ? energy[i - window] : 0);
    if (sum / min(i + 1, window) >= 0.5 * median) {
      entry = i;
      break;
    }
  }
  if (entry < 0) return null;
  final peaks = [...onsets]..sort();
  final threshold = peaks[(0.97 * peaks.length).ceil() - 1];
  int? strongest;
  for (
    var i = max(0, (entry - rate).ceil());
    i <= min(onsets.length - 1, (entry + 0.5 * rate).floor());
    i++
  ) {
    if (onsets[i] > (i == 0 ? 0 : onsets[i - 1]) &&
        onsets[i] >= (i + 1 == onsets.length ? 0 : onsets[i + 1])) {
      if (onsets[i] > threshold) {
        strongest = i;
        break;
      }
      if (strongest == null || onsets[i] > onsets[strongest]) strongest = i;
    }
  }
  return (strongest ?? entry) / rate;
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
  final a1 = alpha(200);
  final a2 = alpha(2500);
  final env = onsetEnvelope(pcm);
  var lp1 = 0.0;
  var lp2 = 0.0;
  var sample = 0;
  final features = <List<double>>[];
  for (final t in starts) {
    final from = (t * sampleRate / 1000).round();
    final to = min(pcm.length, ((t + unitMs) * sampleRate / 1000).round());
    var all = 0.0;
    var low = 0.0;
    var mid = 0.0;
    var high = 0.0;
    var crossings = 0;
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
    final b0 = from ~/ 256;
    final b1 = min(env.length, to ~/ 256);
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
      var before = 0.0;
      var after = 0.0;
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
