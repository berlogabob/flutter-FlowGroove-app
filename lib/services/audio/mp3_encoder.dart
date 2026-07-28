// Platform-resolving export for the share-time MP3 encoder.
//
// Only web needs one: native records AAC and shares `.m4a`, which every
// messenger plays. Browsers can't encode AAC anywhere near universally — Firefox
// and desktop Linux have no WebCodecs AAC at all — so web recordings are WAV,
// and WAV arrives as a document rather than something you can press play on.
//
// MP3 is the one format every browser can produce (via lamejs, pure JS) and
// every messenger plays. Same pattern as `tone_generator.dart`: the native side
// resolves to a stub so `package:web` never enters a native build.
export 'mp3_encoder_stub.dart'
    if (dart.library.js_interop) 'mp3_encoder_web.dart';
