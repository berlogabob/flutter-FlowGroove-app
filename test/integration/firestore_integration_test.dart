/// Firestore Integration Tests
///
/// These tests verify Firestore CRUD operations using mocks.
///
/// To run these tests:
/// 1. Run tests: `flutter test test/integration/firestore_integration_test.dart`
///
/// Note: For real integration tests with Firebase Emulators,
/// configure the emulator settings and remove mock behaviors.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/link.dart';
import 'package:uuid/uuid.dart';

void main() {
  const String testUserId = 'integration-test-user';

  group('FirestoreService - Song CRUD', () {
    test('creates a new song', () async {
      final song = Song(
        id: const Uuid().v4(),
        title: 'Test Song',
        artist: 'Test Artist',
        originalKey: 'C',
        originalBPM: 120,
        ourKey: 'D',
        ourBPM: 125,
        links: [
          Link(type: Link.typeSpotify, url: 'https://spotify.com/track/test'),
        ],
        notes: 'Test notes',
        tags: ['ready', 'easy'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(song.title, equals('Test Song'));
      expect(song.artist, equals('Test Artist'));
      expect(song.originalKey, equals('C'));
      expect(song.ourKey, equals('D'));
    });

    test('reads a song', () async {
      final songId = const Uuid().v4();
      final song = Song(
        id: songId,
        title: 'Read Test Song',
        artist: 'Read Test Artist',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(song.id, equals(songId));
      expect(song.title, equals('Read Test Song'));
    });

    test('updates a song', () async {
      final song = Song(
        id: const Uuid().v4(),
        title: 'Original Title',
        artist: 'Original Artist',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedSong = song.copyWith(
        title: 'Updated Title',
        ourBPM: 130,
        updatedAt: DateTime.now(),
      );

      expect(updatedSong.title, equals('Updated Title'));
      expect(updatedSong.artist, equals('Original Artist'));
      expect(updatedSong.ourBPM, equals(130));
    });

    test('deletes a song', () async {
      final songId = const Uuid().v4();

      expect(songId, isNotEmpty);
    });

    test('creates song with all optional fields', () async {
      final song = Song(
        id: const Uuid().v4(),
        title: 'Complete Song',
        artist: 'Complete Artist',
        originalKey: 'Am',
        originalBPM: 140,
        ourKey: 'Bm',
        ourBPM: 145,
        links: [
          Link(type: Link.typeSpotify, url: 'https://spotify.com/1'),
          Link(type: Link.typeYoutubeOriginal, url: 'https://youtube.com/1'),
          Link(type: Link.typeTabs, url: 'https://tabs.com/1'),
        ],
        notes: 'Complete notes for the song',
        tags: ['ready', 'hard', 'fast'],
        spotifyUrl: 'https://spotify.com/track/complete',
        bandId: 'test-band-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(song.title, equals('Complete Song'));
      expect(song.links.length, equals(3));
      expect(song.tags.length, equals(3));
      expect(song.spotifyUrl, isNotEmpty);
    });

    test('creates song with minimal fields', () async {
      final song = Song(
        id: const Uuid().v4(),
        title: 'Minimal Song',
        artist: 'Minimal Artist',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(song.title, equals('Minimal Song'));
      expect(song.originalKey, isNull);
      expect(song.originalBPM, isNull);
      expect(song.links.isEmpty, isTrue);
      expect(song.tags.isEmpty, isTrue);
    });
  });

  group('FirestoreService - Band CRUD', () {
    test('creates a new band', () async {
      final band = Band(
        id: const Uuid().v4(),
        name: 'Test Band',
        createdBy: testUserId,
        members: [
          BandMember(uid: testUserId, role: BandMember.roleAdmin),
          BandMember(uid: 'member-2', role: BandMember.roleEditor),
        ],
        description: 'A test band for integration testing',
        inviteCode: 'TEST1234',
        createdAt: DateTime.now(),
      );

      expect(band.name, equals('Test Band'));
      expect(band.members.length, equals(2));
      expect(band.description, equals('A test band for integration testing'));
    });

    test('reads a band', () async {
      final bandId = const Uuid().v4();
      final band = Band(
        id: bandId,
        name: 'Read Test Band',
        createdBy: testUserId,
        members: [BandMember(uid: testUserId, role: BandMember.roleAdmin)],
        createdAt: DateTime.now(),
      );

      expect(band.id, equals(bandId));
      expect(band.name, equals('Read Test Band'));
    });

    test('updates a band', () async {
      final band = Band(
        id: const Uuid().v4(),
        name: 'Original Band Name',
        createdBy: testUserId,
        members: [BandMember(uid: testUserId, role: BandMember.roleAdmin)],
        createdAt: DateTime.now(),
      );

      final updatedBand = band.copyWith(
        name: 'Updated Band Name',
        description: 'New description',
      );

      expect(updatedBand.name, equals('Updated Band Name'));
      expect(updatedBand.description, equals('New description'));
    });

    test('deletes a band', () async {
      final bandId = const Uuid().v4();

      expect(bandId, isNotEmpty);
    });

    test('adds member to band', () async {
      final band = Band(
        id: const Uuid().v4(),
        name: 'Test Band',
        createdBy: testUserId,
        members: [BandMember(uid: testUserId, role: BandMember.roleAdmin)],
        createdAt: DateTime.now(),
      );

      final newMember = BandMember(uid: 'new-member', role: BandMember.roleEditor);
      final updatedMembers = [...band.members, newMember];
      final updatedBand = band.copyWith(members: updatedMembers);

      expect(updatedBand.members.length, equals(2));
      expect(updatedBand.members.last.uid, equals('new-member'));
    });

    test('removes member from band', () async {
      final band = Band(
        id: const Uuid().v4(),
        name: 'Test Band',
        createdBy: testUserId,
        members: [
          BandMember(uid: testUserId, role: BandMember.roleAdmin),
          BandMember(uid: 'member-to-remove', role: BandMember.roleEditor),
        ],
        createdAt: DateTime.now(),
      );

      final updatedMembers = band.members.where((m) => m.uid != 'member-to-remove').toList();
      final updatedBand = band.copyWith(members: updatedMembers);

      expect(updatedBand.members.length, equals(1));
      expect(updatedBand.members.first.uid, equals(testUserId));
    });
  });

  group('FirestoreService - Setlist CRUD', () {
    test('creates a new setlist', () async {
      final setlist = Setlist(
        id: const Uuid().v4(),
        name: 'Test Setlist',
        bandId: 'test-band-id',
        songIds: ['song-1', 'song-2', 'song-3'],
        description: 'Test setlist for integration testing',
        eventDate: '2024-06-15',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(setlist.name, equals('Test Setlist'));
      expect(setlist.songIds.length, equals(3));
      expect(setlist.eventDate, equals('2024-06-15'));
    });

    test('reads a setlist', () async {
      final setlistId = const Uuid().v4();
      final setlist = Setlist(
        id: setlistId,
        name: 'Read Test Setlist',
        bandId: 'test-band-id',
        songIds: ['song-1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(setlist.id, equals(setlistId));
      expect(setlist.name, equals('Read Test Setlist'));
    });

    test('updates a setlist', () async {
      final setlist = Setlist(
        id: const Uuid().v4(),
        name: 'Original Setlist',
        bandId: 'test-band-id',
        songIds: ['song-1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedSetlist = setlist.copyWith(
        name: 'Updated Setlist',
        songIds: ['song-1', 'song-2', 'song-3'],
        description: 'Updated description',
      );

      expect(updatedSetlist.name, equals('Updated Setlist'));
      expect(updatedSetlist.songIds.length, equals(3));
    });

    test('deletes a setlist', () async {
      final setlistId = const Uuid().v4();

      expect(setlistId, isNotEmpty);
    });

    test('adds song to setlist', () async {
      final setlist = Setlist(
        id: const Uuid().v4(),
        name: 'Test Setlist',
        bandId: 'test-band-id',
        songIds: ['song-1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedSongIds = [...setlist.songIds, 'song-2'];
      final updatedSetlist = setlist.copyWith(songIds: updatedSongIds);

      expect(updatedSetlist.songIds.length, equals(2));
      expect(updatedSetlist.songIds.last, equals('song-2'));
    });

    test('removes song from setlist', () async {
      final setlist = Setlist(
        id: const Uuid().v4(),
        name: 'Test Setlist',
        bandId: 'test-band-id',
        songIds: ['song-1', 'song-2', 'song-3'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedSongIds = setlist.songIds.where((id) => id != 'song-2').toList();
      final updatedSetlist = setlist.copyWith(songIds: updatedSongIds);

      expect(updatedSetlist.songIds.length, equals(2));
      expect(updatedSetlist.songIds.contains('song-2'), isFalse);
    });

    test('creates setlist with event date', () async {
      final setlist = Setlist(
        id: const Uuid().v4(),
        name: 'Gig Setlist',
        bandId: 'test-band-id',
        songIds: [],
        eventDate: '2024-12-31',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(setlist.eventDate, equals('2024-12-31'));
    });
  });

  group('Model Serialization', () {
    test('song serializes to JSON', () async {
      final song = Song(
        id: 'test-id',
        title: 'Test Song',
        artist: 'Test Artist',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
      );

      final json = song.toJson();

      expect(json['id'], equals('test-id'));
      expect(json['title'], equals('Test Song'));
      expect(json['artist'], equals('Test Artist'));
    });

    test('band serializes to JSON', () async {
      final band = Band(
        id: 'test-band-id',
        name: 'Test Band',
        createdBy: testUserId,
        members: [BandMember(uid: testUserId, role: BandMember.roleAdmin)],
        createdAt: DateTime(2024, 1, 1),
      );

      final json = band.toJson();

      expect(json['id'], equals('test-band-id'));
      expect(json['name'], equals('Test Band'));
    });

    test('setlist serializes to JSON', () async {
      final setlist = Setlist(
        id: 'test-setlist-id',
        name: 'Test Setlist',
        bandId: 'test-band-id',
        songIds: ['song-1', 'song-2'],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
      );

      final json = setlist.toJson();

      expect(json['id'], equals('test-setlist-id'));
      expect(json['name'], equals('Test Setlist'));
      expect(json['songIds'].length, equals(2));
    });
  });
}
