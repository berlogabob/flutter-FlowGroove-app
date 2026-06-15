import '../models/metronome_tempo_range.dart';

class TapTempoCalculator {
  TapTempoCalculator({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const int maxTaps = 8;
  static const Duration timeout = Duration(milliseconds: 2500);

  final DateTime Function() _clock;
  final List<DateTime> _taps = <DateTime>[];

  int? tap() {
    final now = _clock();
    if (_taps.isNotEmpty && now.difference(_taps.last) > timeout) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length > maxTaps) _taps.removeAt(0);
    if (_taps.length < 2) return null;

    var intervals = List<int>.generate(
      _taps.length - 1,
      (index) => _taps[index + 1].difference(_taps[index]).inMilliseconds,
    );
    if (intervals.length >= 4) {
      final sorted = List<int>.from(intervals)..sort();
      intervals = sorted.sublist(1, sorted.length - 1);
    }
    final average = intervals.reduce((a, b) => a + b) / intervals.length;
    return MetronomeTempoRange.clamp(60000 / average);
  }

  void reset() => _taps.clear();
}
