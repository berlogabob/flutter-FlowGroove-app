// MusicBrainz Service Tests
// Exercises the merged http-based service with an injected MockClient.

import 'dart:convert';

import 'package:flowgroove/models/musicbrainz_error.dart';
import 'package:flowgroove/services/musicbrainz_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final recordingJson = {
    'id': 'mb-recording-1',
    'title': 'Test Song',
    'artist-credit': [
      {
        'artist': {'id': 'artist-1', 'name': 'Test Artist'},
      },
    ],
    'releases': [
      {'id': 'release-1', 'title': 'Test Album'},
    ],
    'length': 180000,
  };

  http.Response okResponse(List<Map<String, dynamic>> recordings) =>
      http.Response(
        json.encode({'recordings': recordings}),
        200,
        headers: {'Content-Type': 'application/json'},
      );

  group('MusicBrainzService.searchRecording', () {
    test('returns parsed recordings and sends title+artist query', () async {
      Uri? requested;
      final service = MusicBrainzService(
        client: MockClient((request) async {
          requested = request.url;
          return okResponse([recordingJson]);
        }),
      );

      final results = await service.searchRecording(
        title: 'Test Song',
        artist: 'Test Artist',
      );

      expect(results, hasLength(1));
      expect(results.first.id, 'mb-recording-1');
      expect(results.first.title, 'Test Song');
      expect(results.first.artist, 'Test Artist');
      expect(results.first.album, 'Test Album');
      expect(results.first.lengthMs, 180000);
      // Prefix-friendly query: tokens ANDed, last one wildcarded, so partial
      // autocomplete input ("hit the li") still matches (#75/#78).
      expect(requested!.queryParameters['query'],
          'recording:(Test AND Song*) AND artist:"Test Artist"');
    });

    test('throws ServerError on 500', () async {
      final service = MusicBrainzService(
        client: MockClient((request) async => http.Response('boom', 500)),
      );

      await expectLater(
        service.searchRecording(title: 'x'),
        throwsA(isA<ServerError>()),
      );
    });

    test('throws RateLimitError with retry-after on 429', () async {
      final service = MusicBrainzService(
        client: MockClient(
          (request) async =>
              http.Response('slow down', 429, headers: {'retry-after': '3'}),
        ),
      );

      await expectLater(
        service.searchRecording(title: 'x'),
        throwsA(
          isA<RateLimitError>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 3),
          ),
        ),
      );
    });

    test('wraps transport failures in NetworkError', () async {
      final service = MusicBrainzService(
        client: MockClient((request) async {
          throw http.ClientException('no network');
        }),
      );

      await expectLater(
        service.searchRecording(title: 'x'),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('MusicBrainzService.searchFlexible', () {
    test('returns [] for blank query without any request', () async {
      var calls = 0;
      final service = MusicBrainzService(
        client: MockClient((request) async {
          calls++;
          return okResponse([]);
        }),
      );

      expect(await service.searchFlexible('   '), isEmpty);
      expect(calls, 0);
    });

    test('returns first non-empty cascade result', () async {
      final service = MusicBrainzService(
        client: MockClient((request) async => okResponse([recordingJson])),
      );

      final results = await service.searchFlexible('Test Song!');
      expect(results, hasLength(1));
      expect(results.first.title, 'Test Song');
    });

    test('falls through query shapes when earlier ones are empty', () async {
      final queries = <String>[];
      final service = MusicBrainzService(
        client: MockClient((request) async {
          final q = request.url.queryParameters['query']!;
          queries.add(q);
          // Only the plain-text fallback returns results.
          return q == 'Test Song'
              ? okResponse([recordingJson])
              : okResponse([]);
        }),
      );
      service.resetRateLimit();

      final results = await service.searchFlexible('Test Song');
      expect(results, hasLength(1));
      expect(queries, [
        'recording:"Test Song"',
        'recording:Test Song OR artist:Test Song',
        'Test Song',
      ]);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
