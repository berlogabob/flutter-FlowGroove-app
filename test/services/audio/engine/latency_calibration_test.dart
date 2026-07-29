import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowgroove/services/audio/engine/latency_calibration.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('effective offset combines user offset and per-route default', () async {
    final prefs = await SharedPreferences.getInstance();
    final cal = LatencyCalibration(prefs: prefs);
    cal.setUserOffsetMs(10);
    expect(cal.effectiveOffsetMs(AudioRoute.speaker), 10);
    expect(cal.effectiveOffsetMs(AudioRoute.bluetooth), 160);
  });

  test('user offset persists across instances', () async {
    final prefs = await SharedPreferences.getInstance();
    LatencyCalibration(prefs: prefs).setUserOffsetMs(33);
    expect(LatencyCalibration(prefs: prefs).userOffsetMs, 33);
  });

  test('effectiveOffsetFrames converts ms to frames at sample rate', () async {
    final prefs = await SharedPreferences.getInstance();
    final cal = LatencyCalibration(prefs: prefs);
    expect(cal.effectiveOffsetFrames(AudioRoute.speaker, 48000), 0);
    expect(cal.effectiveOffsetFrames(AudioRoute.wired, 48000), 960); // 20ms
  });
}
