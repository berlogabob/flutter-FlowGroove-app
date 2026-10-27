import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const _maxCachedFiles = 60;

/// Stable short file name for a URL (FNV-1a, 64 bit); no extra dependency.
String midiCacheName(String url) {
  // BigInt keeps the 64-bit math exact on web (int literals above 2^53 do not
  // compile to JavaScript) and yields the same names as the native int path.
  final mask = (BigInt.one << 64) - BigInt.one;
  final prime = BigInt.parse('100000001b3', radix: 16);
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  for (final unit in url.codeUnits) {
    hash = ((hash ^ BigInt.from(unit)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

bool _looksLikeMidi(Uint8List bytes) =>
    bytes.length >= 14 &&
    bytes[0] == 0x4D &&
    bytes[1] == 0x54 &&
    bytes[2] == 0x68 &&
    bytes[3] == 0x64;

Future<Directory> _defaultDir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}/midi_cache');
  await dir.create(recursive: true);
  return dir;
}

/// Returns the MIDI file for [url], from an on-device file when present so a
/// gig with no (or bad) venue Wi-Fi still opens the launchpad. A file behind a
/// URL never changes (a re-import gets a new URL). Writes are atomic and a
/// cached file that is not a MIDI file is treated as a miss. Web has no
/// cache here (the browser HTTP cache applies).
Future<Uint8List> cachedMidiBytes(
  String url,
  Future<Uint8List> Function(String url) fetch, {
  Future<Directory> Function()? cacheDir,
}) async {
  if (kIsWeb) return fetch(url);
  File? file;
  try {
    final dir = await (cacheDir ?? _defaultDir)();
    file = File('${dir.path}/${midiCacheName(url)}.mid');
    if (await file.exists()) {
      final hit = await file.readAsBytes();
      if (_looksLikeMidi(hit)) return hit;
      await file.delete();
    }
  } on Object catch (error) {
    debugPrint('[MidiCache] read failed: $error');
  }
  final bytes = await fetch(url);
  final target = file;
  if (target != null && _looksLikeMidi(bytes)) {
    try {
      final temp = File('${target.path}.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(target.path);
      await _prune(target.parent);
    } on Object catch (error) {
      debugPrint('[MidiCache] write failed: $error');
    }
  }
  return bytes;
}

Future<void> _prune(Directory dir) async {
  final files = <File>[
    await for (final entity in dir.list())
      if (entity is File && entity.path.endsWith('.mid')) entity,
  ];
  if (files.length <= _maxCachedFiles) return;
  files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
  for (final old in files.take(files.length - _maxCachedFiles)) {
    await old.delete();
  }
}
