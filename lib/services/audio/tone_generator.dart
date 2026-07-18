// Platform-resolving export for the tuner reference-tone generator.
//
// On web (`dart.library.js_interop` available) this resolves to the Web Audio
// API oscillator implementation — flutter_soloud has no web path, so the
// SoLoud generator is silent there. On native it resolves to the SoLoud
// implementation and `package:web` is never pulled into native builds.
// Same pattern as `web_audio_engine.dart` (metronome).
export 'tone_generator_soloud.dart'
    if (dart.library.js_interop) 'tone_generator_web.dart';
