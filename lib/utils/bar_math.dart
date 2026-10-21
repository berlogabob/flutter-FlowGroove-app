/// Frame-exact helpers for the click grid.
///
/// Mirrors the Android click grid (`Math.round(j * intervalFrames)` in
/// `MetronomeEngine.kt`): each tick lands on `epochFrame + round(j *
/// intervalFrames)`, so these bars re-anchor to that same frame grid instead
/// of accumulating rounding drift.
double tickIntervalFrames(double intervalMicros, int sampleRate) {
  return intervalMicros * sampleRate / 1_000_000.0;
}

int barFrame({
  required int bar,
  required int ticksPerBar,
  required double intervalMicros,
  required int sampleRate,
  required int epochFrame,
}) {
  return epochFrame +
      (bar * ticksPerBar * tickIntervalFrames(intervalMicros, sampleRate)).round();
}
