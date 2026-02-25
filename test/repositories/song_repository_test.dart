import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/link.dart';
import 'mock_repositories.dart';

void main() {
  group('MockSongRepository', () {
    late MockSongRepository repository;

    setUp(() {
      repository = MockSongRepository();
    });

    group('saveSong', () {
      test('should save a song successfully', () async {
        // Arrange
        final song = Song(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        await repository.saveSong(song);

        // Assert
        expect(repository.songs.length, 1);
        expect(repository.songs.first.id, 'test-id');
        expect(repository.songs.first.title, 'Test Song');
      });
    });

    group('updateSong', () {
      test('should update an existing song', () async {
        // Arrange
        final song = Song(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.saveSong(song);

        // Act
        final updatedSong = song.copyWith(title: 'Updated Title');
        await repository.updateSong(updatedSong);

        // Assert
        expect(repository.songs.first.title, 'Updated Title');
      });

      test('should throw when updating non-existent song', () async {
        // Arrange
        final song = Song(
          id: 'non-existent',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () => repository.updateSong(song),
          throwsException,
        );
      });
    });

    group('deleteSong', () {
      test('should delete an existing song', () async {
        // Arrange
        final song = Song(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.saveSong(song);

        // Act
        await repository.deleteSong('test-id');

        // Assert
        expect(repository.songs.isEmpty, true);
      });
    });

    group('watchSongs', () {
      test('should emit list of songs', () async {
        // Arrange
        final song1 = Song(
          id: 'id1',
          title: 'Song 1',
          artist: 'Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final song2 = Song(
          id: 'id2',
          title: 'Song 2',
          artist: 'Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.saveSong(song1);
        await repository.saveSong(song2);

        // Act
        final songs = await repository.watchSongs('user-id').first;

        // Assert
        expect(songs.length, 2);
      });

      test('should emit empty list when no songs', () async {
        // Act
        final songs = await repository.watchSongs('user-id').first;

        // Assert
        expect(songs.isEmpty, true);
      });
    });

    group('band songs', () {
      test('should add song to band', () async {
        // Arrange
        final song = Song(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        await repository.addSongToBand(
          song: song,
          bandId: 'band-id',
          contributorName: 'Test User',
        );

        // Assert
        expect(repository.getBandSongs('band-id').length, 1);
      });

      test('should add song to band by ID', () async {
        // Arrange
        final song = Song(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.saveSong(song);

        // Act
        await repository.addSongToBandById('test-id', 'band-id');

        // Assert
        expect(repository.getBandSongs('band-id').length, 1);
      });

      test('should delete song from band', () async {
        // Arrange
        final song = Song(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.addSongToBand(
          song: song,
          bandId: 'band-id',
        );

        // Act
        await repository.deleteBandSong('band-id', 'test-id');

        // Assert
        expect(repository.getBandSongs('band-id').isEmpty, true);
      });

      test('should update song in band', () async {
        // Arrange
        final song = Song(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.addSongToBand(
          song: song,
          bandId: 'band-id',
        );

        // Act
        final updatedSong = song.copyWith(title: 'Updated Title');
        await repository.updateBandSong(updatedSong, 'band-id');

        // Assert
        expect(
          repository.getBandSongs('band-id').first.title,
          'Updated Title',
        );
      });

      test('should watch band songs', () async {
        // Arrange
        final song = Song(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.addSongToBand(
          song: song,
          bandId: 'band-id',
        );

        // Act
        final songs = await repository.watchBandSongs('band-id').first;

        // Assert
        expect(songs.length, 1);
        expect(songs.first.title, 'Test Song');
      });
    });
  });

  group('Song model with repository', () {
    test('should preserve metronome settings through save/update', () async {
      // Arrange
      final repository = MockSongRepository();
      final song = Song(
        id: 'test-id',
        title: 'Test Song',
        artist: 'Test Artist',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        accentBeats: 4,
        regularBeats: 4,
      );

      // Act
      await repository.saveSong(song);
      final updatedSong = song.copyWith(ourBPM: 120);
      await repository.updateSong(updatedSong);

      // Assert
      expect(repository.songs.first.accentBeats, 4);
      expect(repository.songs.first.regularBeats, 4);
      expect(repository.songs.first.ourBPM, 120);
    });

    test('should preserve links through save/update', () async {
      // Arrange
      final repository = MockSongRepository();
      final song = Song(
        id: 'test-id',
        title: 'Test Song',
        artist: 'Test Artist',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        links: [
          Link(type: Link.typeOther, url: 'https://example.com', title: 'Example'),
        ],
      );

      // Act
      await repository.saveSong(song);
      final updatedSong = song.copyWith(title: 'New Title');
      await repository.updateSong(updatedSong);

      // Assert
      expect(repository.songs.first.links.length, 1);
      expect(repository.songs.first.links.first.url, 'https://example.com');
    });
  });
}
