import 'package:flutter/services.dart';
import 'latency_calibration.dart';

class AudioRouteMonitor {
  AudioRouteMonitor({EventChannel? channel})
      : _channel = channel ?? const EventChannel('com.flowgroove/audio_route');

  final EventChannel _channel;
  AudioRoute _current = AudioRoute.speaker;

  AudioRoute get current => _current;

  static AudioRoute parse(Object? raw) {
    switch (raw) {
      case 'bluetooth':
        return AudioRoute.bluetooth;
      case 'wired':
        return AudioRoute.wired;
      default:
        return AudioRoute.speaker;
    }
  }

  Stream<AudioRoute> get routeChanges =>
      _channel.receiveBroadcastStream().map((e) => _current = parse(e));
}
