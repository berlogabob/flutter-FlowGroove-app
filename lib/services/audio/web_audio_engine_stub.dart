// Native (non-web) stub for the Web Audio metronome engine.
//
// The real implementation lives in `audio_engine_web.dart` and depends on
// `package:web`, which must not be compiled into native builds. This stub
// provides an API-compatible no-op so the shared `web_audio_engine.dart`
// conditional export resolves on every platform. It is never instantiated at
// runtime on native — the metronome only selects the Web Audio client when
// `kIsWeb` is true.
class AudioEngine {
  Future<void> initialize() async {}

  Future<void> preWarmPlayers() async {}

  Future<void> playClick({
    required bool isAccent,
    required String waveType,
    required double volume,
    double? accentFrequency,
    double? beatFrequency,
  }) async {}

  Future<void> playTest() async {}

  void dispose() {}
}
