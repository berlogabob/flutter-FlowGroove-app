import 'package:shared_preferences/shared_preferences.dart';

enum AudioRoute { speaker, wired, bluetooth }

class LatencyCalibration {
  LatencyCalibration({required SharedPreferences prefs}) : _prefs = prefs {
    _userOffsetMs = _prefs.getInt(_key) ?? 0;
  }

  static const _key = 'metronome_latency_offset_ms';
  final SharedPreferences _prefs;
  int _userOffsetMs = 0;

  int get userOffsetMs => _userOffsetMs;

  void setUserOffsetMs(int ms) {
    _userOffsetMs = ms;
    _prefs.setInt(_key, ms);
  }

  int defaultForRoute(AudioRoute r) {
    switch (r) {
      case AudioRoute.speaker:
        return 0;
      case AudioRoute.wired:
        return 20;
      case AudioRoute.bluetooth:
        return 150;
    }
  }

  int effectiveOffsetMs(AudioRoute r) => _userOffsetMs + defaultForRoute(r);

  int effectiveOffsetFrames(AudioRoute r, int sampleRate) =>
      (effectiveOffsetMs(r) / 1000 * sampleRate).round();
}
