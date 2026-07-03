import 'dart:convert';
import 'dart:io';

import 'package:flowgroove/services/musicbrainz_service.dart';
import 'package:flowgroove/services/song_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('partial title "hit the li" yields suggestions end-to-end (#75/#78)',
      () async {
    // Real MusicBrainz payload for recording:(hit AND the AND li*), captured
    // 2026-07-03. Exercises URL shape + parsing + fuzzy filter together.
    final fixture = File(
      'test/fixtures/musicbrainz_hit_the_li.json',
    ).readAsStringSync();

    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        fixture,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = SongSuggestionService(
      musicBrainz: MusicBrainzService(client: client),
    );

    final suggestions = await service.getSuggestions(query: 'hit the li');

    // The query must be prefix-friendly, not a quoted phrase (which returns
    // zero results from MusicBrainz for partial words).
    expect(requested.queryParameters['query'], contains('li*'));
    expect(requested.queryParameters['query'], isNot(contains('"')));

    expect(suggestions, isNotEmpty);
    expect(
      suggestions.first.title.toLowerCase(),
      startsWith('hit the li'),
    );
    // No unrelated (e.g. Cyrillic) titles sneak in.
    for (final s in suggestions) {
      expect(s.title.toLowerCase(), contains('hit the li'));
    }

    final decoded = jsonDecode(fixture) as Map<String, dynamic>;
    expect((decoded['recordings'] as List).length, 3);
  });
}
