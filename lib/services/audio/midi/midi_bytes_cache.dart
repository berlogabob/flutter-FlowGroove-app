import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const _maxCachedFiles = 60;

/// Stable short file name for a URL (FNV-1a, 64 bit); no extra dependency.
String midiCacheName(String url) {
  var hash = 0xcbf29ce484222325;
  for (final unit in url.codeUnits) {
    hash ^= unit;
    hash *= 0x100000001b3;
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
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
