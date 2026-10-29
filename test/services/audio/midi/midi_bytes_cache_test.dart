import 'dart:io';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/midi/midi_bytes_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('midi_cache'));
  tearDown(() async => dir.delete(recursive: true));

  Future<Directory> dirFn() async => dir;
  final bytes = Uint8List.fromList([
    ...'MThd'.codeUnits,
    0, 0, 0, 6, 0, 1, 0, 1, 1, 0xE0, // header
  ]);

  test('fetches once, then serves from disk', () async {
    var calls = 0;
    Future<Uint8List> fetch(String _) async {
      calls++;
      return bytes;
    }

    expect(await cachedMidiBytes('u', fetch, cacheDir: dirFn), bytes);
    expect(await cachedMidiBytes('u', fetch, cacheDir: dirFn), bytes);
    expect(calls, 1);
  });

  test('works offline once cached', () async {
    await cachedMidiBytes('u', (_) async => bytes, cacheDir: dirFn);
    final offline = await cachedMidiBytes(
      'u',
      (_) async => throw const SocketException('offline'),
      cacheDir: dirFn,
    );
    expect(offline, bytes);
  });

  test('offline and not cached still fails honestly', () async {
    expect(
      cachedMidiBytes(
        'other',
        (_) async => throw const SocketException('offline'),
        cacheDir: dirFn,
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test('a corrupt cached file is refetched', () async {
    await File('${dir.path}/${midiCacheName('u')}.mid').writeAsBytes([1, 2, 3]);
    expect(
      await cachedMidiBytes('u', (_) async => bytes, cacheDir: dirFn),
      bytes,
    );
  });

  test('falls back to the network when the cache directory fails', () async {
    expect(
      await cachedMidiBytes(
        'u',
        (_) async => bytes,
        cacheDir: () async => throw StateError('no storage'),
      ),
      bytes,
    );
  });

  test('different urls get different files', () {
    expect(midiCacheName('a'), isNot(midiCacheName('b')));
    expect(midiCacheName('a'), midiCacheName('a'));
  });
}
