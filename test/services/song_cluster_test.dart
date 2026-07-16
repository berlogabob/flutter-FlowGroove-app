import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_duplicate.dart';
import 'package:flowgroove/services/matching/song_cluster.dart';
import 'package:flowgroove/services/matching/song_merge_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song(
  String id, {
  String title = 'Song',
  String? key,
  int? bpm,
  List<String> tags = const [],
  String? canonicalSongId,
  int year = 2024,
}) => Song(
  id: id,
  title: title,
  artist: 'Artist',
  ourKey: key,
  ourBPM: bpm,
  tags: tags,
  canonicalSongId: canonicalSongId,
  createdAt: DateTime(year),
  updatedAt: DateTime(year),
);

SongDuplicateCandidate _pair(Song a, Song b, {double score = 90}) =>
    SongDuplicateCandidate(
      source: a,
      match: b,
      score: score,
      confidence: SongDuplicateConfidence.strong,
    );

void main() {
  group('clusterCandidates (#81)', () {
    test('chained pairs fold into one cluster (A-B, B-C → A,B,C)', () {
      final a = _song('a', year: 2022);
      final b = _song('b', year: 2023);
      final c = _song('c', year: 2024);

      final clusters = clusterCandidates([_pair(a, b), _pair(b, c)]);

      expect(clusters, hasLength(1));
      expect(clusters.single.songs.map((s) => s.id), ['a', 'b', 'c']);
      expect(clusters.single.pairKeys, hasLength(2));
    });

    test('independent pairs stay separate clusters', () {
      final clusters = clusterCandidates([
        _pair(_song('a'), _song('b')),
        _pair(_song('x'), _song('y')),
      ]);
      expect(clusters, hasLength(2));
    });

    test('bigger clusters sort first', () {
      final clusters = clusterCandidates([
        _pair(_song('x'), _song('y'), score: 99),
        _pair(_song('a'), _song('b')),
        _pair(_song('b'), _song('c')),
      ]);
      expect(clusters.first.songs, hasLength(3));
      expect(clusters.last.maxScore, 99);
    });
  });

  group('SongMergeResolver.mergeCluster (#81)', () {
    const resolver = SongMergeResolver();

    test('keeper of many prefers canonical link, then oldest', () {
      final old = _song('old', year: 2020);
      final linked = _song('linked', canonicalSongId: 'c1', year: 2024);
      expect(
        resolver.preferredKeeperOfMany([old, linked, _song('z')]).id,
        'linked',
      );
      expect(
        resolver.preferredKeeperOfMany([old, _song('z', year: 2023)]).id,
        'old',
      );
    });

    test('per-field picks land in the merged song; tags union', () {
      final a = _song('a', title: 'Hey Joe', key: 'Em', tags: ['rock'], year: 2020);
      final b = _song('b', title: 'Hey Joe!', bpm: 82, tags: ['live'], year: 2021);
      final c = _song('c', title: 'hey joe (cover)', tags: ['rock', 'jam'], year: 2022);

      final merged = resolver.mergeCluster(
        [a, b, c],
        keeper: a,
        picks: {
          ClusterField.title: 1, // b's title
          ClusterField.ourBpm: 1, // b's bpm
        },
      );

      expect(merged.id, 'a'); // keeper identity survives
      expect(merged.title, 'Hey Joe!');
      expect(merged.ourBPM, 82);
      expect(merged.ourKey, 'Em'); // unpicked → keeper
      expect(merged.tags, containsAll(['rock', 'live', 'jam']));
      expect(merged.createdAt, DateTime(2020));
    });
  });
}
