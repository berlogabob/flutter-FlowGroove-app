// Platform-resolving export: waveform peaks for an imported song file.
// Same pattern as `mp3_encoder.dart` — web decodes with the browser, native
// with SoLoud's decoder, so `package:web` never enters a native build.
export 'song_peaks_native.dart'
    if (dart.library.js_interop) 'song_peaks_web.dart';
