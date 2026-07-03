// DeezerService tests — BPM autofill source (no-auth public API).
// Uses MockClient; no real network calls.

import 'dart:convert';

import 'package:flowgroove/services/api/deezer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    DeezerService.client = http.Client();
  });

  MockClient mockDeezer({
    List<Map<String, dynamic>>? searchResults,
    Map<String, dynamic>? track,
  }) {
    return MockClient((request) async {
      if (request.url.path == '/search') {
        return http.Response(json.encode({'data': searchResults ?? []}), 200);
      }
      if (request.url.path.startsWith('/track/')) {
        return http.Response(json.encode(track ?? {}), 200);
      }
      return http.Response('not found', 404);
    });
  }

  group('DeezerService.getBpm', () {
    test('returns rounded BPM for a confident match', () async {
      DeezerService.client = mockDeezer(
        searchResults: [
          {
            'id': 136338502,
            'title': 'Ride The Lightning (Remastered)',
            'artist': {'name': 'Metallica'},
          },
        ],
        track: {'id': 136338502, 'bpm': 149.8},
      );

      final bpm = await DeezerService.getBpm(
        title: 'Ride the Lightning',
        artist: 'Metallica',
      );
      expect(bpm, 150);
    });

    test('returns null when Deezer has no BPM (bpm == 0)', () async {
      DeezerService.client = mockDeezer(
        searchResults: [
          {
            'id': 1,
            'title': 'Ride the Lightning',
            'artist': {'name': 'Metallica'},
          },
        ],
        track: {'id': 1, 'bpm': 0},
      );

      final bpm = await DeezerService.getBpm(
        title: 'Ride the Lightning',
        artist: 'Metallica',
      );
      expect(bpm, isNull);
    });

    test('returns null when results do not match the requested song', () async {
      DeezerService.client = mockDeezer(
        searchResults: [
          {
            'id': 2,
            'title': 'Completely Different Song',
            'artist': {'name': 'Someone Else'},
          },
        ],
        track: {'id': 2, 'bpm': 120},
      );

      final bpm = await DeezerService.getBpm(
        title: 'Ride the Lightning',
        artist: 'Metallica',
      );
      expect(bpm, isNull);
    });

    test('returns null on network error instead of throwing', () async {
      DeezerService.client = MockClient((_) async {
        throw http.ClientException('boom');
      });

      final bpm = await DeezerService.getBpm(
        title: 'Ride the Lightning',
        artist: 'Metallica',
      );
      expect(bpm, isNull);
    });

    test('returns null for empty title', () async {
      final bpm = await DeezerService.getBpm(title: '', artist: 'Metallica');
      expect(bpm, isNull);
    });
  });
}
