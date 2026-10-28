import 'dart:io';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/audio_file_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('audio_cache_test');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => root.path,
    );
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test(
    'coalesces downloads and reuses an object across token changes',
    () async {
      var fetches = 0;
      Future<Uint8List> fetch(String _) async {
        fetches++;
        return Uint8List.fromList([1, 2, 3]);
      }

      const url = 'https://storage.test/b/bucket/o/lab_audio%2Ftake.wav';
      final files = await Future.wait([
        audioFileCache('$url?token=old', fetch),
        audioFileCache('$url?token=new', fetch),
      ]);
      expect(fetches, 1);
      expect(files.first!.path, files.last!.path);
      expect(await files.first!.readAsBytes(), [1, 2, 3]);
      await files.first!.setLastModified(DateTime(2000));
      await audioFileCache('$url?token=third', fetch);
      expect(fetches, 1);
      expect((await files.first!.lastModified()).year, greaterThan(2000));
      final version = await audioFileCache('${url}_v2', fetch);
      expect(version!.path, isNot(files.first!.path));
      expect(fetches, 2);
      expect(
        await root.list(recursive: true).any((f) => f.path.endsWith('.tmp')),
        false,
      );
    },
  );

  test('failed downloads can be retried', () async {
    const url = 'https://storage.test/o/retry.wav';
    await expectLater(
      audioFileCache(url, (_) async => throw const SocketException('offline')),
      throwsA(isA<SocketException>()),
    );
    final file = await audioFileCache(
      url,
      (_) async => Uint8List.fromList([7]),
    );
    expect(await file!.readAsBytes(), [7]);
  });

  test('null audio decodes PCM without disk caching', () async {
    final samples = Int16List.fromList([1, -1]);
    var decodes = 0;
    Future<Int16List?> decode() async {
      decodes++;
      return samples;
    }

    expect(await cachedPcm22k(null, decode), same(samples));
    expect(await cachedPcm22k(null, decode), same(samples));
    expect(decodes, 2);
  });

  test('PCM survives reopening as raw little endian int16', () async {
    final audio = await audioFileCache(
      'https://storage.test/o/pcm.wav',
      (_) async => Uint8List.fromList([1]),
    );
    final samples = Int16List.fromList([-32768, -1, 0, 32767]);
    var decodes = 0;
    Future<Int16List?> decode() async {
      decodes++;
      return samples;
    }

    expect(await cachedPcm22k(audio, decode), samples);
    expect(await cachedPcm22k(audio, decode), samples);
    expect(decodes, 1);
    final sidecar = File(
      audio!.path.replaceFirst(RegExp(r'\.wav$'), '.pcm22k'),
    );
    expect(await sidecar.readAsBytes(), [0, 128, 255, 255, 0, 0, 255, 127]);
  });

  test('evicts the oldest file beyond 500 MB', () async {
    final directory = Directory('${root.path}/audio');
    await directory.create();
    final oldest = File('${directory.path}/old.wav');
    final handle = await oldest.open(mode: FileMode.write);
    await handle.truncate(500 * 1024 * 1024);
    await handle.close();
    await oldest.setLastModified(DateTime(2000));
    final audio = await audioFileCache(
      'https://storage.test/o/current.wav',
      (_) async => Uint8List.fromList([1]),
    );
    expect(await oldest.exists(), false);
    expect(await audio!.exists(), true);
  });
}
