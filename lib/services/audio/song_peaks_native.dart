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

/// The whole song as mono 16-bit PCM at [sampleRate], for playing it inside
/// the click engine. Null when it can't be decoded (AAC/m4a natively).
///
/// SoLoud returns samples equally spaced in time, so asking for exactly
/// duration × rate samples doubles as the resample to the engine rate.
/// ponytail: nearest-sample resampling, fine for a practice backing; a real
/// resampler if anyone hears aliasing.
Future<Int16List?> decodeSongPcm(
  Uint8List bytes, {
  required int sampleRate,
  required int durationMs,
}) async {
  try {
    final count = durationMs * sampleRate ~/ 1000;
    if (count <= 0) return null;
    final samples = await SoLoud.instance.readSamplesFromMem(bytes, count);
    return samples.isEmpty ? null : pcm16FromFloats(samples);
  } catch (_) {
    return null;
  }
}
