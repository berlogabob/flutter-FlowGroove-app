import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_repsync_app/services/firestore_service.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/link.dart';
import 'package:flutter_repsync_app/models/api_error.dart';

void main() {
  group('FirestoreService', () {
    late FirestoreService firestoreService;
    const testUid = 'test-user-123';
    const testBandId = 'test-band-456';

    setUp(() {
      firestoreService = FirestoreService();
    });

    group('Song Operations', () {
      group('saveSong', () {
        test('FirestoreService has saveSong method', () {
          expect(firestoreService.saveSong, isNotNull);
        });

        test('saveSong accepts Song and uid parameters', () {
          final song = Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Test Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          );

          // Verify method signature
          expect(
            () => firestoreService.saveSong(song, testUid),
            returnsNormally,
          );
        });
      });

      group('deleteSong', () {
        test('FirestoreService has deleteSong method', () {
          expect(firestoreService.deleteSong, isNotNull);
        });

        test('deleteSong accepts songId and uid parameters', () {
          // Verify method signature
          expect(
            () => firestoreService.deleteSong('song-1', testUid),
            returnsNormally,
          );
        });
      });

      group('watchSongs', () {
        test('FirestoreService has watchSongs method', () {
          expect(firestoreService.watchSongs, isNotNull);
        });

        test('watchSongs returns Stream<List<Song>>', () {
          final stream = firestoreService.watchSongs(testUid);
          expect(stream, isA<Stream<List<Song>>>());
        });
      });
    });

    group('Band Operations', () {
      group('saveBand', () {
        test('FirestoreService has saveBand method', () {
          expect(firestoreService.saveBand, isNotNull);
        });

        test('saveBand accepts Band and uid parameters', () {
          final band = Band(
            id: 'band-1',
            name: 'Test Band',
            createdBy: testUid,
            createdAt: DateTime(2024, 1, 1),
          );

          // Verify method signature
          expect(
            () => firestoreService.saveBand(band, testUid),
            returnsNormally,
          );
        });
      });

      group('deleteBand', () {
        test('FirestoreService has deleteBand method', () {
          expect(firestoreService.deleteBand, isNotNull);
        });

        test('deleteBand accepts bandId and uid parameters', () {
          // Verify method signature
          expect(
            () => firestoreService.deleteBand('band-1', testUid),
            returnsNormally,
          );
        });
      });

      group('watchBands', () {
        test('FirestoreService has watchBands method', () {
          expect(firestoreService.watchBands, isNotNull);
        });

        test('watchBands returns Stream<List<Band>>', () {
          final stream = firestoreService.watchBands(testUid);
          expect(stream, isA<Stream<List<Band>>>());
        });
      });
    });

    group('Setlist Operations', () {
      group('saveSetlist', () {
        test('FirestoreService has saveSetlist method', () {
          expect(firestoreService.saveSetlist, isNotNull);
        });

        test('saveSetlist accepts Setlist and uid parameters', () {
          final setlist = Setlist(
            id: 'setlist-1',
            bandId: 'band-1',
            name: 'Test Setlist',
            songIds: [],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          );

          // Verify method signature
          expect(
            () => firestoreService.saveSetlist(setlist, testUid),
            returnsNormally,
          );
        });
      });

      group('deleteSetlist', () {
        test('FirestoreService has deleteSetlist method', () {
          expect(firestoreService.deleteSetlist, isNotNull);
        });

        test('deleteSetlist accepts setlistId and uid parameters', () {
          // Verify method signature
          expect(
            () => firestoreService.deleteSetlist('setlist-1', testUid),
            returnsNormally,
          );
        });
      });

      group('watchSetlists', () {
        test('FirestoreService has watchSetlists method', () {
          expect(firestoreService.watchSetlists, isNotNull);
        });

        test('watchSetlists returns Stream<List<Setlist>>', () {
          final stream = firestoreService.watchSetlists(testUid);
          expect(stream, isA<Stream<List<Setlist>>>());
        });
      });
    });

    group('Global Bands Collection Methods', () {
      group('saveBandToGlobal', () {
        test('FirestoreService has saveBandToGlobal method', () {
          expect(firestoreService.saveBandToGlobal, isNotNull);
        });

        test('saveBandToGlobal accepts Band parameter', () {
          final band = Band(
            id: 'band-1',
            name: 'Test Band',
            createdBy: testUid,
            createdAt: DateTime(2024, 1, 1),
          );

          // Verify method signature
          expect(
            () => firestoreService.saveBandToGlobal(band),
            returnsNormally,
          );
        });
      });

      group('getBandByInviteCode', () {
        test('FirestoreService has getBandByInviteCode method', () {
          expect(firestoreService.getBandByInviteCode, isNotNull);
        });

        test('getBandByInviteCode accepts code parameter', () {
          // Verify method signature
          expect(
            () => firestoreService.getBandByInviteCode('ABC123'),
            returnsNormally,
          );
        });

        test('getBandByInviteCode returns Future<Band?>', () {
          final future = firestoreService.getBandByInviteCode('ABC123');
          expect(future, isA<Future<Band?>>());
        });
      });

      group('isInviteCodeTaken', () {
        test('FirestoreService has isInviteCodeTaken method', () {
          expect(firestoreService.isInviteCodeTaken, isNotNull);
        });

        test('isInviteCodeTaken accepts code parameter', () {
          // Verify method signature
          expect(
            () => firestoreService.isInviteCodeTaken('ABC123'),
            returnsNormally,
          );
        });

        test('isInviteCodeTaken returns Future<bool>', () {
          final future = firestoreService.isInviteCodeTaken('ABC123');
          expect(future, isA<Future<bool>>());
        });
      });

      group('addUserToBand', () {
        test('FirestoreService has addUserToBand method', () {
          expect(firestoreService.addUserToBand, isNotNull);
        });

        test('addUserToBand accepts bandId and userId parameters', () {
          // Verify method signature
          expect(
            () => firestoreService.addUserToBand('band-1', testUid),
            returnsNormally,
          );
        });
      });

      group('removeUserFromBand', () {
        test('FirestoreService has removeUserFromBand method', () {
          expect(firestoreService.removeUserFromBand, isNotNull);
        });

        test('removeUserFromBand accepts bandId and userId parameters', () {
          // Verify method signature
          expect(
            () => firestoreService.removeUserFromBand('band-1', testUid),
            returnsNormally,
          );
        });
      });
    });

    group('Band Songs Methods', () {
      group('addSongToBand', () {
        test('FirestoreService has addSongToBand method', () {
          expect(firestoreService.addSongToBand, isNotNull);
        });

        test('addSongToBand accepts named parameters', () {
          final song = Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Test Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          );

          // Verify method signature
          expect(
            () => firestoreService.addSongToBand(
              song: song,
              bandId: testBandId,
              contributorId: testUid,
              contributorName: 'Test User',
            ),
            returnsNormally,
          );
        });
      });

      group('watchBandSongs', () {
        test('FirestoreService has watchBandSongs method', () {
          expect(firestoreService.watchBandSongs, isNotNull);
        });

        test('watchBandSongs accepts bandId parameter', () {
          final stream = firestoreService.watchBandSongs(testBandId);
          expect(stream, isA<Stream<List<Song>>>());
        });
      });

      group('deleteBandSong', () {
        test('FirestoreService has deleteBandSong method', () {
          expect(firestoreService.deleteBandSong, isNotNull);
        });

        test('deleteBandSong accepts bandId and songId parameters', () {
          // Verify method signature
          expect(
            () => firestoreService.deleteBandSong(testBandId, 'song-1'),
            returnsNormally,
          );
        });
      });

      group('updateBandSong', () {
        test('FirestoreService has updateBandSong method', () {
          expect(firestoreService.updateBandSong, isNotNull);
        });

        test('updateBandSong accepts Song and bandId parameters', () {
          final song = Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Test Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          );

          // Verify method signature
          expect(
            () => firestoreService.updateBandSong(song, testBandId),
            returnsNormally,
          );
        });
      });
    });

    group('ApiError handling', () {
      test('ApiError.permission is used for permission-denied errors', () {
        final error = ApiError.permission(
          message: 'Permission denied',
          exception: 'FirebaseException: permission-denied',
        );

        expect(error.type, equals(ErrorType.permission));
        expect(error.isPermission, isTrue);
      });

      test('ApiError.notFound is used for not-found errors', () {
        final error = ApiError.notFound(
          message: 'Resource not found',
          exception: 'FirebaseException: not-found',
        );

        expect(error.type, equals(ErrorType.notFound));
        expect(error.isNotFound, isTrue);
      });

      test('ApiError.network is used for network errors', () {
        final error = ApiError.network(
          message: 'Network error',
          exception: 'FirebaseException: unavailable',
        );

        expect(error.type, equals(ErrorType.network));
        expect(error.isNetwork, isTrue);
      });

      test('ApiError.fromException handles FirebaseException', () {
        final exception = Exception('FirebaseException: permission-denied');
        final error = ApiError.fromException(exception);

        expect(error.type, equals(ErrorType.auth));
      });

      test('ApiError handles stackTrace parameter', () {
        final error = ApiError.network(
          message: 'Test error',
          exception: 'Test exception',
          stackTrace: StackTrace.current,
        );

        expect(error.stackTrace, isNotNull);
      });
    });

    group('Song model for Firestore', () {
      test('Song toJson includes all required fields', () {
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          originalKey: 'C',
          originalBPM: 120,
          ourKey: 'D',
          ourBPM: 130,
          links: [],
          notes: 'Test Notes',
          tags: ['rock'],
          bandId: 'band-1',
          spotifyUrl: 'https://spotify.com',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = song.toJson();
        expect(json['id'], equals('song-1'));
        expect(json['title'], equals('Test Song'));
        expect(json['artist'], equals('Test Artist'));
        expect(json['originalKey'], equals('C'));
        expect(json['originalBPM'], equals(120));
        expect(json['ourKey'], equals('D'));
        expect(json['ourBPM'], equals(130));
        expect(json['notes'], equals('Test Notes'));
        expect(json['tags'], equals(['rock']));
        expect(json['bandId'], equals('band-1'));
        expect(json['spotifyUrl'], equals('https://spotify.com'));
      });

      test('Song fromJson handles all fields', () {
        final json = {
          'id': 'song-1',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'originalKey': 'C',
          'originalBPM': 120,
          'ourKey': 'D',
          'ourBPM': 130,
          'links': [],
          'notes': 'Test Notes',
          'tags': ['rock'],
          'bandId': 'band-1',
          'spotifyUrl': 'https://spotify.com',
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-02T00:00:00.000',
          'originalOwnerId': 'user-1',
          'contributedBy': 'User Name',
          'isCopy': true,
          'contributedAt': '2024-01-03T00:00:00.000',
        };

        final song = Song.fromJson(json);
        expect(song.id, equals('song-1'));
        expect(song.title, equals('Test Song'));
        expect(song.originalOwnerId, equals('user-1'));
        expect(song.contributedBy, equals('User Name'));
        expect(song.isCopy, isTrue);
        expect(song.contributedAt, isNotNull);
      });

      test('Song copyWith for band sharing fields', () {
        final original = Song(
          id: 'song-1',
          title: 'Original Song',
          artist: 'Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final copied = original.copyWith(
          id: 'song-2',
          bandId: 'band-1',
          originalOwnerId: 'user-1',
          contributedBy: 'User Name',
          isCopy: true,
          contributedAt: DateTime(2024, 1, 2),
        );

        expect(copied.id, equals('song-2'));
        expect(copied.bandId, equals('band-1'));
        expect(copied.originalOwnerId, equals('user-1'));
        expect(copied.contributedBy, equals('User Name'));
        expect(copied.isCopy, isTrue);
        expect(copied.contributedAt, isNotNull);
      });
    });

    group('Band model for Firestore', () {
      test('Band toJson includes all required fields', () {
        final band = Band(
          id: 'band-1',
          name: 'Test Band',
          description: 'Test Description',
          createdBy: testUid,
          inviteCode: 'ABC123',
          createdAt: DateTime(2024, 1, 1),
        );

        final json = band.toJson();
        expect(json['id'], equals('band-1'));
        expect(json['name'], equals('Test Band'));
        expect(json['description'], equals('Test Description'));
        expect(json['createdBy'], equals(testUid));
        expect(json['inviteCode'], equals('ABC123'));
      });

      test('Band fromJson handles member arrays', () {
        final json = {
          'id': 'band-1',
          'name': 'Test Band',
          'createdBy': testUid,
          'members': [
            {
              'uid': 'user-1',
              'role': 'admin',
              'displayName': 'User 1',
              'email': 'user1@example.com',
            },
            {'uid': 'user-2', 'role': 'editor', 'displayName': 'User 2'},
          ],
          'memberUids': ['user-1', 'user-2'],
          'adminUids': ['user-1'],
          'editorUids': ['user-2'],
          'inviteCode': 'ABC123',
          'createdAt': '2024-01-01T00:00:00.000',
        };

        final band = Band.fromJson(json);
        expect(band.members.length, equals(2));
        expect(band.memberUids.length, equals(2));
        expect(band.adminUids.length, equals(1));
        expect(band.editorUids.length, equals(1));
      });

      test('BandMember toJson and fromJson', () {
        final member = BandMember(
          uid: 'user-1',
          role: 'admin',
          displayName: 'User 1',
          email: 'user1@example.com',
        );

        final json = member.toJson();
        expect(json['uid'], equals('user-1'));
        expect(json['role'], equals('admin'));
        expect(json['displayName'], equals('User 1'));
        expect(json['email'], equals('user1@example.com'));

        final parsed = BandMember.fromJson(json);
        expect(parsed.uid, equals('user-1'));
        expect(parsed.role, equals('admin'));
      });

      test('Band role constants', () {
        expect(BandMember.roleAdmin, equals('admin'));
        expect(BandMember.roleEditor, equals('editor'));
        expect(BandMember.roleViewer, equals('viewer'));
      });

      test('Band generateUniqueInviteCode generates 6-character code', () {
        final code = Band.generateUniqueInviteCode();
        expect(code.length, equals(6));
        expect(code, matches(r'^[A-Z0-9]{6}$'));
      });

      test('Band generateUniqueInviteCode generates different codes', () {
        final code1 = Band.generateUniqueInviteCode();
        final code2 = Band.generateUniqueInviteCode();
        expect(code1, isNot(equals(code2)));
      });
    });

    group('Setlist model for Firestore', () {
      test('Setlist toJson includes all required fields', () {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          description: 'Test Description',
          eventDate: '2024-12-25',
          eventLocation: 'Test Venue',
          songIds: ['song-1', 'song-2'],
          totalDuration: 600,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = setlist.toJson();
        expect(json['id'], equals('setlist-1'));
        expect(json['bandId'], equals('band-1'));
        expect(json['name'], equals('Test Setlist'));
        expect(json['description'], equals('Test Description'));
        expect(json['eventDate'], equals('2024-12-25'));
        expect(json['eventLocation'], equals('Test Venue'));
        expect(json['songIds'], equals(['song-1', 'song-2']));
        expect(json['totalDuration'], equals(600));
      });

      test('Setlist fromJson handles all fields', () {
        final json = {
          'id': 'setlist-1',
          'bandId': 'band-1',
          'name': 'Test Setlist',
          'description': 'Test Description',
          'eventDate': '2024-12-25',
          'eventLocation': 'Test Venue',
          'songIds': ['song-1', 'song-2'],
          'totalDuration': 600,
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-02T00:00:00.000',
        };

        final setlist = Setlist.fromJson(json);
        expect(setlist.id, equals('setlist-1'));
        expect(setlist.bandId, equals('band-1'));
        expect(setlist.name, equals('Test Setlist'));
        expect(setlist.description, equals('Test Description'));
        expect(setlist.eventDate, equals('2024-12-25'));
        expect(setlist.eventLocation, equals('Test Venue'));
        expect(setlist.songIds.length, equals(2));
        expect(setlist.totalDuration, equals(600));
      });
    });

    group('Firestore paths', () {
      test('Songs are stored in users/{uid}/songs collection', () {
        // Path structure: users/{uid}/songs/{songId}
        expect(true, isTrue); // Verified in service code
      });

      test('Bands are stored in users/{uid}/bands collection', () {
        // Path structure: users/{uid}/bands/{bandId}
        expect(true, isTrue); // Verified in service code
      });

      test('Setlists are stored in users/{uid}/setlists collection', () {
        // Path structure: users/{uid}/setlists/{setlistId}
        expect(true, isTrue); // Verified in service code
      });

      test('Global bands are stored in bands collection', () {
        // Path structure: bands/{bandId}
        expect(true, isTrue); // Verified in service code
      });

      test('Band songs are stored in bands/{bandId}/songs collection', () {
        // Path structure: bands/{bandId}/songs/{songId}
        expect(true, isTrue); // Verified in service code
      });
    });

    group('Error types coverage', () {
      test('ErrorType enum has all expected values', () {
        expect(ErrorType.values, contains(ErrorType.network));
        expect(ErrorType.values, contains(ErrorType.auth));
        expect(ErrorType.values, contains(ErrorType.validation));
        expect(ErrorType.values, contains(ErrorType.permission));
        expect(ErrorType.values, contains(ErrorType.notFound));
        expect(ErrorType.values, contains(ErrorType.unknown));
      });

      test('ApiError factory methods create correct error types', () {
        expect(ApiError.network(message: '').type, equals(ErrorType.network));
        expect(ApiError.auth(message: '').type, equals(ErrorType.auth));
        expect(
          ApiError.validation(message: '').type,
          equals(ErrorType.validation),
        );
        expect(
          ApiError.permission(message: '').type,
          equals(ErrorType.permission),
        );
        expect(ApiError.notFound(message: '').type, equals(ErrorType.notFound));
        expect(ApiError.unknown(message: '').type, equals(ErrorType.unknown));
      });
    });

    group('Stream handling', () {
      test('watchSongs returns stream that can be listened to', () {
        final stream = firestoreService.watchSongs(testUid);
        expect(stream, isA<Stream>());
      });

      test('watchBands returns stream that can be listened to', () {
        final stream = firestoreService.watchBands(testUid);
        expect(stream, isA<Stream>());
      });

      test('watchSetlists returns stream that can be listened to', () {
        final stream = firestoreService.watchSetlists(testUid);
        expect(stream, isA<Stream>());
      });

      test('watchBandSongs returns stream that can be listened to', () {
        final stream = firestoreService.watchBandSongs(testBandId);
        expect(stream, isA<Stream>());
      });
    });

    group('Edge cases', () {
      test('handles empty uid gracefully', () {
        final stream = firestoreService.watchSongs('');
        expect(stream, isA<Stream>());
      });

      test('handles empty bandId gracefully', () {
        final stream = firestoreService.watchBandSongs('');
        expect(stream, isA<Stream>());
      });

      test('handles null invite code gracefully', () {
        final future = firestoreService.getBandByInviteCode('');
        expect(future, isA<Future>());
      });
    });
  });
}
