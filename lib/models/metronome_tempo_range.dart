/// Shared tempo limits for every metronome input surface.
class MetronomeTempoRange {
  const MetronomeTempoRange._();

  static const int minimum = 1;
  static const int maximum = 400;
  static const String label = '$minimum-$maximum';

  static bool contains(int bpm) => bpm >= minimum && bpm <= maximum;

  static int clamp(num bpm) {
    return bpm.round().clamp(minimum, maximum);
  }
}
