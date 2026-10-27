import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_note_edit.dart';

/// Waveform peaks for an imported song file, or null when it can't be
/// decoded. WAV is read directly; mp3/flac/ogg go through SoLoud's decoder.
/// AAC/m4a have no decoder there and stay without a waveform.
Future<List<int>?> decodeSongPeaks(Uint8List bytes) async {
  final wav = peaksFromWav(bytes);
  if (wav != null) return wav;
  try {
    // Point samples, not averages: averaging signed audio cancels to ~0.
    // ponytail: 8000 points is a rough envelope; enough to see sections.
    final samples = await SoLoud.instance.readSamplesFromMem(bytes, 8000);
    final peaks = peaksFromFloats(samples);
    return peaks.isEmpty ? null : peaks;
  } catch (_) {
    return null;
  }
}
