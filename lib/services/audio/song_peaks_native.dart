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
/// records in, at 128 kbps for small, trimmable practice audio. Android only;
/// null elsewhere or when the file can't be decoded (upload the original then).
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
      'bitrate': 128000,
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

/// A WAV of [startMs, endMs) of the song at [audioPath], for a gapless loop:
/// just_audio repeats a whole WAV sample-exact, while a clip of compressed
/// audio re-seeks on every pass (an audible gap). The song is decoded once to
/// a full WAV beside [audioPath]; each loop is a byte slice of it. Android
/// only; null elsewhere or on failure (the caller falls back to a clip).
Future<String?> loopWav(String audioPath, int startMs, int endMs) async {
  if (!Platform.isAndroid || endMs <= startMs) return null;
  try {
    final full = await songWav(audioPath);
    final base = full.path;
    final source = await full.open();
    try {
      final header = ByteData.sublistView(await source.read(44));
      final channels = header.getUint16(22, Endian.little);
      final rate = header.getUint32(24, Endian.little);
      final dataBytes = header.getUint32(40, Endian.little);
      final frame = channels * 2;
      int at(int ms) => (ms * rate ~/ 1000 * frame).clamp(0, dataBytes);
      final from = at(startMs), length = at(endMs) - from;
      if (length <= 0) return null;
      final dir = await getTemporaryDirectory();
      final out = File(
        '${dir.path}/loop_${base.hashCode}_${startMs}_$endMs.wav',
      );
      if (!out.existsSync()) {
        await source.setPosition(44 + from);
        final wav = BytesBuilder(copy: false)
          ..add(_wavHeader(length, rate, channels))
          ..add(await source.read(length));
        await out.writeAsBytes(wav.takeBytes(), flush: true);
      }
      // Older loops: the player has moved on (Android keeps an open file
      // readable after unlink).
      for (final old in dir.listSync().whereType<File>()) {
        final name = old.uri.pathSegments.last;
        if (name.startsWith('loop_') && old.path != out.path) old.deleteSync();
      }
      return out.path;
    } finally {
      await source.close();
    }
  } catch (e) {
    // ignore: avoid_print
    print('loopWav failed: $e');
    return null;
  }
}

Uint8List _wavHeader(int dataBytes, int rate, int channels) {
  final header = ByteData(44);
  void ascii(int at, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(at + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVEfmt ');
  header
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * channels * 2, Endian.little)
    ..setUint16(32, channels * 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, dataBytes, Endian.little);
  return header.buffer.asUint8List();
}

final _songWavs = <String, Future<File>>{};

/// The whole song at [audioPath] as a WAV beside it, decoded once. Call early
/// so the first loop doesn't wait for the decode.
Future<File> songWav(String audioPath) {
  final dot = audioPath.lastIndexOf('.');
  final base = dot > audioPath.lastIndexOf('/')
      ? audioPath.substring(0, dot)
      : audioPath;
  final full = File('$base.full.wav');
  return _songWavs.putIfAbsent(audioPath, () async {
    try {
      if (!full.existsSync()) {
        final part = File('${full.path}.part');
        await _audio.invokeMapMethod<String, Object?>('toWav', {
          'in': audioPath,
          'out': part.path,
        });
        await part.rename(full.path);
      }
      return full;
    } catch (_) {
      _songWavs.remove(audioPath);
      rethrow;
    }
  });
}
