import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'audio_note_edit.dart';

/// Waveform peaks for an imported song file, decoded by the browser, which
/// handles every format it can play (mp3, m4a/aac, wav, ogg, flac).
Future<List<int>?> decodeSongPeaks(Uint8List bytes) async {
  final context = web.OfflineAudioContext(1.toJS, 1, 44100);
  try {
    // decodeAudioData detaches the buffer it is given, so hand it a copy.
    final buffer = await context
        .decodeAudioData(Uint8List.fromList(bytes).buffer.toJS)
        .toDart;
    final peaks = peaksFromFloats(buffer.getChannelData(0).toDart);
    return peaks.isEmpty ? null : peaks;
  } catch (_) {
    return null;
  }
}
