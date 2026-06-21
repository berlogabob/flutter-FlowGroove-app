import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/latency_calibration.dart';
import 'package:flowgroove/services/audio/engine/audio_route_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('maps native route strings to AudioRoute', () {
    expect(AudioRouteMonitor.parse('bluetooth'), AudioRoute.bluetooth);
    expect(AudioRouteMonitor.parse('wired'), AudioRoute.wired);
    expect(AudioRouteMonitor.parse('speaker'), AudioRoute.speaker);
    expect(AudioRouteMonitor.parse('garbage'), AudioRoute.speaker); // safe default
  });
}
