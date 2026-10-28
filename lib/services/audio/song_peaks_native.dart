import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_note_edit.dart';

const _audio = MethodChannel('com.flowgroove/audio');

/// ADTS AAC: syncword plus layer bits 00 (MPEG audio, i.e. mp3, has 01..11).
bool _isAdts(Uint8List bytes) =>
    bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xF6) == 0xF0;

/// AAC (what imports are converted to) through Android's decoder; SoLoud has
/// no AAC decoder. Null elsewhere or on failure.
Future<Int16List?> _platformPcm(Uint8List bytes, int sampleRate) async {
  if (!Platform.isAndroid) return null;
  final file = File(
    '${(await getTemporaryDirectory()).path}/'
    'decode_${DateTime.now().microsecondsSinceEpoch}.aac',
  );
  try {
    await file.writeAsBytes(bytes);
    final pcm = await _audio.invokeMethod<Uint8List>('decodePcm', {
      'in': file.path,
      'sampleRate': sampleRate,
    });
    if (pcm == null || pcm.isEmpty) return null;
    return Int16List.view(Uint8List.fromList(pcm).buffer, 0, pcm.length ~/ 2);
  } catch (e) {
    // ignore: avoid_print
    print('decodePcm failed: $e');
    return null;
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}

/// Re-encodes the picked file at [path] to ADTS AAC, the format the app
/// records in, so imports are small and trimmable. Android only; null
/// elsewhere or when the file can't be decoded (upload the original then).
Future<({Uint8List bytes, List<int> peaks, int durationMs, int primingMs})?>
transcodeToAac(String path) async {
  if (!Platform.isAndroid) return null;
  final out = File(
    '${(await getTemporaryDirectory()).path}/'
    'import_${DateTime.now().microsecondsSinceEpoch}.aac',
  );
  try {
    final result = await _audio.invokeMapMethod<String, Object?>('toAac', {
      'in': path,
      'out': out.path,
      'bitrate': 192000,
    });
    final bytes = await out.readAsBytes();
    if (result == null || bytes.isEmpty) return null;
    return (
      bytes: bytes,
      peaks: [for (final p in result['peaks']! as List) p as int],
      durationMs: (result['durationMs']! as num).toInt(),
      primingMs: (result['primingMs'] as num? ?? 0).toInt(),
    );
  } catch (e) {
    // ignore: avoid_print
    print('transcodeToAac failed: $e');
    return null;
  } finally {
    if (out.existsSync()) out.deleteSync();
  }
}

/// Waveform peaks for an imported song file, or null when it can't be
/// decoded. WAV is read directly; mp3/flac/ogg go through SoLoud's decoder,
/// AAC through the platform's.
Future<List<int>?> decodeSongPeaks(Uint8List bytes) async {
  final wav = peaksFromWav(bytes);
  if (wav != null) return wav;
  if (_isAdts(bytes)) {
    // 1 kHz is plenty for 200 bars.
    final pcm = await _platformPcm(bytes, 1000);
    if (pcm == null) return null;
    final floats = Float32List(pcm.length);
    for (var i = 0; i < pcm.length; i++) {
      floats[i] = pcm[i] / 32768;
    }
    final peaks = peaksFromFloats(floats);
    return peaks.isEmpty ? null : peaks;
  }
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
/// the click engine. Null when it can't be decoded.
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
  if (_isAdts(bytes)) return _platformPcm(bytes, sampleRate);
  try {
    final count = durationMs * sampleRate ~/ 1000;
    if (count <= 0) return null;
    final samples = await SoLoud.instance.readSamplesFromMem(bytes, count);
    return samples.isEmpty ? null : pcm16FromFloats(samples);
  } catch (e) {
    // ignore: avoid_print
    print('decodeSongPcm failed: $e');
    return null;
  }
}
