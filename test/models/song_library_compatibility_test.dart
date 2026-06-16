import 'package:flowgroove/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Song library compatibility', () {
    test('legacy song docs parse without v2 metadata', () {
      final song = Song.fromJson({
        'id': 'song-1',
        'title': 'Legacy Song',
        'artist': 'Legacy Artist',
        'createdAt': DateTime(2026, 5, 11).toIso8601String(),
        'updatedAt': DateTime(2026, 5, 12).toIso8601String(),
      });

      expect(song.id, 'song-1');
      expect(song.title, 'Legacy Song');
      expect(song.canonicalSongId, isNull);
      expect(song.libraryBaseRevision, isNull);
      expect(song.latestCommitId, isNull);
    });

    test('linked song metadata survives serialization', () {
      final song = Song(
        id: 'library-1',
        title: 'Linked Song',
        artist: 'Linked Artist',
        canonicalSongId: 'canonical-1',
        libraryBaseRevision: 7,
        latestCommitId: 'commit-9',
        createdAt: DateTime(2026, 5, 11),
        updatedAt: DateTime(2026, 5, 12),
      );

      final restored = Song.fromJson(song.toJson());

      expect(restored.canonicalSongId, 'canonical-1');
      expect(restored.libraryBaseRevision, 7);
      expect(restored.latestCommitId, 'commit-9');
    });
  });
}
