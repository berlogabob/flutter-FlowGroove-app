import 'package:flutter/foundation.dart';

import 'backing_engine.dart';
import 'backing_engine_platform.dart';

BackingEngine createBackingEngine() =>
    defaultTargetPlatform == TargetPlatform.android
    ? PlatformBackingEngine()
    : StubBackingEngine();

/// Unsupported platforms retain their existing playback path.
class StubBackingEngine implements BackingEngine {
  @override
  Stream<BackingState> get states => const Stream.empty();

  @override
  Stream<int> get bars => const Stream.empty();

  @override
  Future<int> engineSampleRate() async => 44100;

  @override
  Future<void> load(BackingStems stems) async => throw UnsupportedError(
    'Backing playback is unavailable on this platform',
  );

  @override
  Future<void> command(BackingCommand c) async {}

  @override
  void setGain(int stem, double gain) {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() async {}
}
