import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/library_song.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_commit.dart';
import 'package:flowgroove/models/song_delta.dart';

void main() {
  group('LibrarySong', () {
    test('serializes v2 linked song document shape', () {
      final materialized = Song(
        id: 'library-1',
        title: 'Song',
        artist: 'Artist',
        ourBPM: 120,
        canonicalSongId: 'canonical-1',
        createdAt: DateTime(2026, 5, 11),
        updatedAt: DateTime(2026, 5, 12),
      );
      final librarySong = LibrarySong(
        id: 'library-1',
        canonicalSongId: 'canonical-1',
        ownerType: 'user',
        ownerId: 'user-1',
        baseRevision: 4,
        delta: SongDelta(values: {SongDeltaField.ourBPM: 120}),
        materialized: materialized,
        latestCommitId: 'commit-1',
        createdAt: DateTime(2026, 5, 11),
        updatedAt: DateTime(2026, 5, 12),
      );

      final restored = LibrarySong.fromJson(librarySong.toJson());

      expect(restored.schemaVersion, LibrarySong.currentSchemaVersion);
      expect(restored.id, 'library-1');
      expect(restored.canonicalSongId, 'canonical-1');
      expect(restored.ownerType, 'user');
      expect(restored.ownerId, 'user-1');
      expect(restored.baseRevision, 4);
      expect(restored.delta.ourBPM, 120);
      expect(restored.materialized.title, 'Song');
      expect(restored.latestCommitId, 'commit-1');
      expect(restored.isDeleted, isFalse);
    });
  });

  group('SongCommit', () {
    test('serializes linear commit history metadata', () {
      final commit = SongCommit(
        id: 'commit-2',
        parentCommitId: 'commit-1',
        canonicalSongId: 'canonical-1',
        baseRevision: 4,
        delta: SongDelta(values: {SongDeltaField.notes: 'New notes'}),
        operation: 'update',
        authorId: 'user-1',
        message: 'Update linked song',
        createdAt: DateTime(2026, 5, 14),
        clientMutationId: 'mutation-1',
      );

      final restored = SongCommit.fromJson(commit.toJson());

      expect(restored.id, 'commit-2');
      expect(restored.parentCommitId, 'commit-1');
      expect(restored.canonicalSongId, 'canonical-1');
      expect(restored.baseRevision, 4);
      expect(restored.delta.notes, 'New notes');
      expect(restored.operation, 'update');
      expect(restored.authorId, 'user-1');
      expect(restored.message, 'Update linked song');
      expect(restored.clientMutationId, 'mutation-1');
    });
  });
}
