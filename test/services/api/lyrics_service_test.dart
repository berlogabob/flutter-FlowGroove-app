// LyricsService tests — plain lyric-text autofill (lyrics.ovh, no auth).
// Uses MockClient; no real network calls.

import 'dart:convert';

import 'package:flowgroove/services/api/lyrics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    LyricsService.client = http.Client();
  });

  test('returns trimmed lyrics for a 200 response', () async {
    LyricsService.client = MockClient((request) async {
      return http.Response(json.encode({'lyrics': '  line one\nline two  '}), 200);
    });

    final lyrics = await LyricsService.getLyrics(
      title: 'Go With the Flow',
      artist: 'Queens of the Stone Age',
    );
    expect(lyrics, 'line one\nline two');
  });

  test('returns null on 404 (no match)', () async {
    LyricsService.client = MockClient((request) async {
      return http.Response(json.encode({'error': 'No lyrics found'}), 404);
    });

    final lyrics = await LyricsService.getLyrics(title: 'Nope', artist: 'Nobody');
    expect(lyrics, isNull);
  });

  test('returns null when lyrics are blank', () async {
    LyricsService.client = MockClient((request) async {
      return http.Response(json.encode({'lyrics': '   '}), 200);
    });

    final lyrics = await LyricsService.getLyrics(title: 'X', artist: 'Y');
    expect(lyrics, isNull);
  });
}
