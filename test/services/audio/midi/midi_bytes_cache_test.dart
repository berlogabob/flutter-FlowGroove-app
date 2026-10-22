import 'dart:io';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/midi/midi_bytes_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box<dynamic> box;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('midi_cache_test');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('midi_test');
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  final bytes = Uint8List.fromList([1, 2, 3]);

  test('fetches once, then serves from the cache', () async {
    var calls = 0;
    Future<Uint8List> fetch(String _) async {
      calls++;
      return bytes;
    }

    expect(await cachedMidiBytes('u', fetch, openBox: () async => box), bytes);
    expect(await cachedMidiBytes('u', fetch, openBox: () async => box), bytes);
    expect(calls, 1);
  });

  test('works offline once cached', () async {
    await cachedMidiBytes('u', (_) async => bytes, openBox: () async => box);
    final offline = await cachedMidiBytes(
      'u',
      (_) async => throw const SocketException('offline'),
      openBox: () async => box,
    );
    expect(offline, bytes);
  });

  test('offline and not cached still fails honestly', () async {
    expect(
      cachedMidiBytes(
        'other',
        (_) async => throw const SocketException('offline'),
        openBox: () async => box,
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test('falls back to the network when the cache cannot open', () async {
    final got = await cachedMidiBytes(
      'u',
      (_) async => bytes,
      openBox: () async => throw StateError('Hive not initialised'),
    );
    expect(got, bytes);
  });
}
