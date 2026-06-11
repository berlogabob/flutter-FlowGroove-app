import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_duplicate.dart';
import 'package:flowgroove/services/matching/song_duplicate_detector.dart';
import 'package:flowgroove/services/matching/song_merge_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Song song(String id, String title, String artist, {String? variant}) => Song(
    id: id,
    title: title,
    artist: artist,
    variantType: variant,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  test('detects exact normalized name and artist', () {
    final result = const SongDuplicateDetector().compare(
      song('a', 'The Song', 'The Band'),
      song('b', 'The Song', 'Band'),
    );

    expect(result, isNotNull);
    expect(result!.confidence, SongDuplicateConfidence.exact);
  });

  test('keeps different variants in possible review', () {
    final result = const SongDuplicateDetector().compare(
      song('a', 'The Song', 'Band'),
      song('b', 'The Song (Live)', 'Band', variant: 'live'),
    );

    expect(result, isNotNull);
    expect(result!.variantMismatch, isTrue);
    expect(result.confidence, SongDuplicateConfidence.possible);
  });

  test('merge unions tags and links while preserving keeper id', () {
    final first = song('a', 'Song', 'Band').copyWith(tags: ['rock']);
    final second = song('b', 'Song', 'Band').copyWith(tags: ['Rock', 'live']);

    final merged = const SongMergeResolver().merge(first, second);

    expect(merged.id, 'a');
    expect(merged.tags, ['rock', 'live']);
  });
}
