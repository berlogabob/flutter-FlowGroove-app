import 'package:flowgroove/models/event_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses each supported proposal and preserves optional notes', () {
    for (final fields in [
      {'kind': 'add', 'songId': 'song'},
      {'kind': 'remove', 'itemId': 'second'},
      {
        'kind': 'reorder',
        'itemIds': ['second', 'first'],
      },
    ]) {
      final suggestion = EventSuggestion.fromJson({
        'type': fields['kind'],
        'text': 'Please',
        'proposal': {'version': 1, 'baseFingerprint': 'f' * 64, ...fields},
      });
      expect(suggestion.proposal?.kind, fields['kind']);
      expect(suggestion.text, 'Please');
    }
  });
  test('malformed, unknown and legacy proposals remain readable', () {
    final valid = {
      'version': 1,
      'kind': 'remove',
      'baseFingerprint': 'f' * 64,
      'itemId': 'second',
    };
    for (final raw in [
      null,
      'bad',
      <Object?>[],
      <String, Object?>{},
      {...valid, 'version': 2},
      {...valid, 'kind': 'future'},
      {...valid, 'itemId': 2},
      {...valid, 'baseFingerprint': 'bad'},
      {...valid, 'extra': true},
      {
        ...valid,
        'kind': 'reorder',
        'itemIds': ['one', 'one'],
      },
    ]) {
      final suggestion = EventSuggestion.fromJson({
        'type': 'remove',
        'text': 'Keep my note',
        'proposal': raw,
      });
      expect(suggestion.proposal, isNull);
      expect(suggestion.text, 'Keep my note');
    }
    final legacy = EventSuggestion.fromJson({'type': 'note', 'text': 'Encore'});
    expect(legacy.proposal, isNull);
    expect(legacy.action, 'left a note');
    expect(legacy.text, 'Encore');
  });
  test('add without a candidate snapshot falls back to its song id', () {
    final request = EventSuggestion.fromJson({
      'type': 'add',
      'candidate': {'title': 17},
      'proposal': {
        'version': 1,
        'kind': 'add',
        'baseFingerprint': 'f' * 64,
        'songId': 'song-42',
      },
    });
    expect(request.description(), 'Add "song-42"');
  });

  test('rejects invalid add positions and duplicate reorder occurrences', () {
    for (final fields in [
      {'kind': 'add', 'songId': 'song', 'beforeItemId': 4},
      {'kind': 'add', 'songId': 'song/invalid'},
      {'kind': 'remove'},
      {
        'kind': 'reorder',
        'itemIds': ['same', 'same'],
      },
      {
        'kind': 'reorder',
        'itemIds': ['first', 3],
      },
    ]) {
      expect(
        EventSuggestion.fromJson({
          'type': fields['kind'],
          'proposal': {'version': 1, 'baseFingerprint': 'f' * 64, ...fields},
        }).proposal,
        isNull,
      );
    }
  });
}
