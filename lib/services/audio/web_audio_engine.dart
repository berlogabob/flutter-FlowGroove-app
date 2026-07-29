// Platform-resolving export for the Web Audio metronome engine.
//
// On web (`dart.library.js_interop` available) this resolves to the real
// `AudioEngine` backed by the browser Web Audio API. On native it resolves to
// an API-compatible no-op stub so `package:web` is never pulled into native
// builds. This lets `metronome_runtime_providers.dart` reference `AudioEngine`
// unconditionally while keeping the web-only code out of the native graph.
export 'web_audio_engine_stub.dart'
    if (dart.library.js_interop) 'audio_engine_web.dart';
