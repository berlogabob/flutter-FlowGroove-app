import 'dart:math' as math;
import 'dart:typed_data';

/// Suggest song boundaries at the middle of sustained quiet gaps.
List<int> suggestTakeCuts(
  Int16List pcm,
  int sampleRate, {
  int minGapMs = 4000,
  int minTakeMs = 60000,
}) {
  if (pcm.isEmpty || sampleRate <= 0) return const [];
  final window = math.max(1, sampleRate ~/ 4);
  final rms = <double>[];
  for (var start = 0; start < pcm.length; start += window) {
    final end = math.min(start + window, pcm.length);
    var squares = 0.0;
    for (var i = start; i < end; i++) {
      squares += pcm[i] * pcm[i];
    }
    rms.add(math.sqrt(squares / (end - start)));
  }
  final sorted = [...rms]..sort();
  // ponytail: naive threshold; tune on real rehearsals. Cap it below music
  // levels so files with less than 15% silence still have useful gaps.
  final threshold = math.min(
    sorted[((sorted.length - 1) * .15).floor()] * 1.5,
    sorted[((sorted.length - 1) * .85).floor()] * .25,
  );
  final durationMs = pcm.length * 1000 ~/ sampleRate;
  final cuts = <int>[];
  int? gapStart;
  for (var i = 0; i <= rms.length; i++) {
    if (i < rms.length && rms[i] <= threshold) {
      gapStart ??= i * window;
      continue;
    }
    if (gapStart == null) continue;
    final end = math.min(i * window, pcm.length);
    final cut = (gapStart + end) * 1000 ~/ (2 * sampleRate);
    if (gapStart > 0 &&
        end < pcm.length &&
        (end - gapStart) * 1000 >= minGapMs * sampleRate &&
        cut - (cuts.isEmpty ? 0 : cuts.last) >= minTakeMs &&
        durationMs - cut >= minTakeMs) {
      cuts.add(cut);
    }
    gapStart = null;
  }
  return cuts;
}
