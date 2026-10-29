import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

final _downloads = <String, Future<File>>{};
const _maxCacheBytes = 500 * 1024 * 1024;

/// Swapped in widget tests, which can't do real file I/O. Null result = no cache (web).
Future<File?> Function(String url, Future<Uint8List> Function(String) fetch)
audioFileCache = _cachedAudioFile;

Future<File?> _cachedAudioFile(
  String url,
  Future<Uint8List> Function(String) fetch,
) {
  if (kIsWeb) return Future.value(null);
  final uri = Uri.parse(url);
  final marker = uri.path.indexOf('/o/');
  final object = marker < 0
      ? uri.path
      : Uri.decodeComponent(uri.path.substring(marker + 3));
  final scope = marker < 0
      ? uri.host
      : '${uri.host}${uri.path.substring(0, marker)}';
  final key = sha256.convert(utf8.encode('$scope/$object')).toString();
  return _downloads.putIfAbsent(key, () async {
    try {
      final directory = Directory(
        '${(await getApplicationCacheDirectory()).path}/audio',
      );
      await directory.create(recursive: true);
      final extension = object.split('.').last;
      final ext = RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(extension)
          ? '.$extension'
          : '';
      final file = File('${directory.path}/$key$ext');
      if (await file.exists()) {
        await file.setLastModified(DateTime.now());
      } else {
        await _writeAtomic(file, await fetch(url));
      }
      await _evict(directory, keep: file.path);
      return file;
    } finally {
      final _ = _downloads.remove(key);
    }
  });
}

Future<void> _writeAtomic(File file, Uint8List bytes) async {
  final temp = File(
    '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  try {
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  } finally {
    if (await temp.exists()) await temp.delete();
  }
}

Future<void> _evict(Directory directory, {required String keep}) async {
  final files = <(File, FileStat)>[];
  var total = 0;
  await for (final entity in directory.list()) {
    if (entity is! File || entity.path.endsWith('.tmp')) continue;
    final stat = await entity.stat();
    total += stat.size;
    files.add((entity, stat));
  }
  files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
  for (final (file, stat) in files) {
    if (total <= _maxCacheBytes) break;
    if (file.path == keep) continue;
    try {
      await file.delete();
      total -= stat.size;
    } on FileSystemException {
      // Another cache request may already have evicted it.
    }
  }
}

Future<Int16List?> cachedPcm22k(
  File? audio,
  Future<Int16List?> Function() decode,
) async {
  if (audio == null) return decode();
  final dot = audio.path.lastIndexOf('.');
  final hasExtension = dot > audio.path.lastIndexOf(Platform.pathSeparator);
  final file = File(
    '${hasExtension ? audio.path.substring(0, dot) : audio.path}.pcm22k',
  );
  try {
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty && bytes.length.isEven) {
        final data = ByteData.sublistView(bytes);
        final pcm = Int16List(bytes.length ~/ 2);
        for (var i = 0; i < pcm.length; i++) {
          pcm[i] = data.getInt16(i * 2, Endian.little);
        }
        await file.setLastModified(DateTime.now());
        return pcm;
      }
    }
  } on FileSystemException {
    // Decode again if eviction raced the read.
  }
  final pcm = await decode();
  if (pcm == null || pcm.isEmpty) return pcm;
  try {
    final data = ByteData(pcm.length * 2);
    for (var i = 0; i < pcm.length; i++) {
      data.setInt16(i * 2, pcm[i], Endian.little);
    }
    await _writeAtomic(file, data.buffer.asUint8List());
    await _evict(audio.parent, keep: audio.path);
  } on FileSystemException {
    // Analysis still works if the cache cannot be written.
  }
  return pcm;
}
