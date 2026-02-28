import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'mock_repositories.dart';

void main() {
  group('MockBandRepository', () {
    late MockBandRepository repository;

    setUp(() {
      repository = MockBandRepository();
    });

    group('saveBand', () {
      test('should save a band successfully', () async {
        // Arrange
        final band = Band(
          id: 'test-id',
          name: 'Test Band',
          createdBy: 'user-id',
          createdAt: DateTime.now(),
        );

        // Act
        await repository.saveBand(band, uid: 'user-id');

        // Assert
        expect(repository.bands.length, 1);
        expect(repository.bands.first.id, 'test-id');
        expect(repository.bands.first.name, 'Test Band');
      });
    });

    group('deleteBand', () {
      test('should delete an existing band', () async {
        // Arrange
        final band = Band(
          id: 'test-id',
          name: 'Test Band',
          createdBy: 'user-id',
          createdAt: DateTime.now(),
        );
        await repository.saveBand(band, uid: 'user-id');

        // Act
        await repository.deleteBand('test-id', uid: 'user-id');

        // Assert
        expect(repository.bands.isEmpty, true);
      });
    });

    group('watchBands', () {
      test('should emit list of bands for user', () async {
        // Arrange
        final band1 = Band(
          id: 'id1',
          name: 'Band 1',
          createdBy: 'user-id',
          createdAt: DateTime.now(),
        );
        final band2 = Band(
          id: 'id2',
          name: 'Band 2',
          createdBy: 'user-id',
          createdAt: DateTime.now(),
        );
        await repository.saveBand(band1, uid: 'user-id');
        await repository.saveBand(band2, uid: 'user-id');

        // Act
        final bands = await repository.watchBands('user-id').first;

        // Assert
        expect(bands.length, 2);
      });

      test('should emit empty list when user has no bands', () async {
        // Act
        final bands = await repository.watchBands('user-id').first;

        // Assert
        expect(bands.isEmpty, true);
      });
    });

    group('global band operations', () {
      test('should save band to global collection', () async {
        // Arrange
        final band = Band(
          id: 'test-id',
          name: 'Test Band',
          createdBy: 'user-id',
          createdAt: DateTime.now(),
          inviteCode: 'ABC123',
        );

        // Act
        await repository.saveBandToGlobal(band);

        // Assert
        expect(repository.bands.length, 1);
        expect(repository.bands.first.inviteCode, 'ABC123');
      });

      test('should get band by invite code', () async {
        // Arrange
        final band = Band(
          id: 'test-id',
          name: 'Test Band',
          createdBy: 'user-id',
          createdAt: DateTime.now(),
          inviteCode: 'ABC123',
        );
        await repository.saveBandToGlobal(band);

        // Act
        final foundBand = await repository.getBandByInviteCode('ABC123');

        // Assert
        expect(foundBand, isNotNull);
        expect(foundBand!.id, 'test-id');
      });

      test('should return null when invite code not found', () async {
        // Act
        final foundBand = await repository.getBandByInviteCode('NOTEXIST');

        // Assert
        expect(foundBand, isNull);
      });

      test('should check if invite code is taken', () async {
        // Arrange
        final band = Band(
          id: 'test-id',
          name: 'Test Band',
          createdBy: 'user-id',
          createdAt: DateTime.now(),
          inviteCode: 'ABC123',
        );
        await repository.saveBandToGlobal(band);

        // Act & Assert
        expect(await repository.isInviteCodeTaken('ABC123'), true);
        expect(await repository.isInviteCodeTaken('NOTEXIST'), false);
      });
    });

    group('user band membership', () {
      test('should add user to band', () async {
        // Arrange
        final band = Band(
          id: 'test-id',
          name: 'Test Band',
          createdBy: 'user-id',
          createdAt: DateTime.now(),
        );
        await repository.saveBandToGlobal(band);

        // Act
        await repository.addUserToBand('test-id', userId: 'new-user-id');

        // Assert
        final bands = await repository.watchBands('new-user-id').first;
        expect(bands.length, 1);
      });

      test('should remove user from band', () async {
        // Arrange
        final band = Band(
          id: 'test-id',
          name: 'Test Band',
          createdBy: 'user-id',
          createdAt: DateTime.now(),
        );
        await repository.saveBand(band, uid: 'user-id');

        // Act
        await repository.removeUserFromBand('test-id', userId: 'user-id');

        // Assert
        final bands = await repository.watchBands('user-id').first;
        expect(bands.isEmpty, true);
      });
    });
  });

  group('MockSetlistRepository', () {
    late MockSetlistRepository repository;

    setUp(() {
      repository = MockSetlistRepository();
    });

    group('saveSetlist', () {
      test('should save a setlist successfully', () async {
        // Arrange
        final setlist = Setlist(
          id: 'test-id',
          bandId: 'band-id',
          name: 'Test Setlist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        await repository.saveSetlist(setlist);

        // Assert
        expect(repository.setlists.length, 1);
        expect(repository.setlists.first.id, 'test-id');
        expect(repository.setlists.first.name, 'Test Setlist');
      });
    });

    group('deleteSetlist', () {
      test('should delete an existing setlist', () async {
        // Arrange
        final setlist = Setlist(
          id: 'test-id',
          bandId: 'band-id',
          name: 'Test Setlist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.saveSetlist(setlist);

        // Act
        await repository.deleteSetlist('test-id');

        // Assert
        expect(repository.setlists.isEmpty, true);
      });
    });

    group('watchSetlists', () {
      test('should emit list of setlists', () async {
        // Arrange
        final setlist1 = Setlist(
          id: 'id1',
          bandId: 'band-id',
          name: 'Setlist 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final setlist2 = Setlist(
          id: 'id2',
          bandId: 'band-id',
          name: 'Setlist 2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.saveSetlist(setlist1);
        await repository.saveSetlist(setlist2);

        // Act
        final setlists = await repository.watchSetlists('user-id').first;

        // Assert
        expect(setlists.length, 2);
      });

      test('should emit empty list when no setlists', () async {
        // Act
        final setlists = await repository.watchSetlists('user-id').first;

        // Assert
        expect(setlists.isEmpty, true);
      });
    });

    group('Setlist model operations', () {
      test('should preserve song IDs through save', () async {
        // Arrange
        final setlist = Setlist(
          id: 'test-id',
          bandId: 'band-id',
          name: 'Test Setlist',
          songIds: ['song1', 'song2', 'song3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        await repository.saveSetlist(setlist);

        // Assert
        expect(repository.setlists.first.songIds.length, 3);
        expect(repository.setlists.first.songIds, ['song1', 'song2', 'song3']);
      });

      test('should handle optional fields', () async {
        // Arrange
        final setlist = Setlist(
          id: 'test-id',
          bandId: 'band-id',
          name: 'Test Setlist',
          description: 'Test Description',
          eventDate: DateTime(2026, 3, 1),
          eventLocation: 'Test Venue',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        await repository.saveSetlist(setlist);

        // Assert
        expect(repository.setlists.first.description, 'Test Description');
        expect(repository.setlists.first.eventDate, DateTime(2026, 3, 1));
        expect(repository.setlists.first.eventLocation, 'Test Venue');
      });
    });
  });

  group('Band model with repository', () {
    test('should generate unique invite codes', () async {
      // Arrange
      final repository = MockBandRepository();
      final codes = <String>{};

      // Act
      for (int i = 0; i < 100; i++) {
        final code = Band.generateUniqueInviteCode();
        codes.add(code);
      }

      // Assert
      expect(codes.length, 100); // All codes should be unique
    });

    test('should calculate memberUids from members', () async {
      // Arrange
      final band = Band(
        id: 'test-id',
        name: 'Test Band',
        createdBy: 'user-id',
        members: [
          BandMember(uid: 'user1', role: BandMember.roleAdmin),
          BandMember(uid: 'user2', role: BandMember.roleEditor),
          BandMember(uid: 'user3', role: BandMember.roleViewer),
        ],
        createdAt: DateTime.now(),
      );

      // Assert
      expect(band.memberUids.length, 3);
      expect(band.memberUids, contains('user1'));
      expect(band.memberUids, contains('user2'));
      expect(band.memberUids, contains('user3'));
    });

    test('should calculate adminUids from members', () async {
      // Arrange
      final band = Band(
        id: 'test-id',
        name: 'Test Band',
        createdBy: 'user-id',
        members: [
          BandMember(uid: 'user1', role: BandMember.roleAdmin),
          BandMember(uid: 'user2', role: BandMember.roleEditor),
          BandMember(uid: 'user3', role: BandMember.roleAdmin),
        ],
        createdAt: DateTime.now(),
      );

      // Assert
      expect(band.adminUids.length, 2);
      expect(band.adminUids, contains('user1'));
      expect(band.adminUids, contains('user3'));
    });
  });
}
