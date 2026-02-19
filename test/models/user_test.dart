import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/user.dart';

void main() {
  group('AppUser Model', () {
    // Test data
    final testDate = DateTime(2024, 4, 5, 12, 0, 0);
    final testBandIds = ['band-1', 'band-2', 'band-3'];

    group('Constructor', () {
      test('creates AppUser with required fields', () {
        final user = AppUser(
          uid: 'user-id-1',
          createdAt: testDate,
        );

        expect(user.uid, 'user-id-1');
        expect(user.displayName, isNull);
        expect(user.email, isNull);
        expect(user.photoURL, isNull);
        expect(user.bandIds, isEmpty);
        expect(user.createdAt, testDate);
      });

      test('creates AppUser with all optional fields', () {
        final user = AppUser(
          uid: 'user-id-2',
          displayName: 'John Doe',
          email: 'john@example.com',
          photoURL: 'https://example.com/photo.jpg',
          bandIds: testBandIds,
          createdAt: testDate,
        );

        expect(user.uid, 'user-id-2');
        expect(user.displayName, 'John Doe');
        expect(user.email, 'john@example.com');
        expect(user.photoURL, 'https://example.com/photo.jpg');
        expect(user.bandIds.length, 3);
        expect(user.createdAt, testDate);
      });
    });

    group('fromJson', () {
      test('parses complete JSON data correctly', () {
        final json = {
          'uid': 'user-id-3',
          'displayName': 'Jane Smith',
          'email': 'jane@example.com',
          'photoURL': 'https://example.com/jane.jpg',
          'bandIds': ['band-a', 'band-b'],
          'createdAt': testDate.toIso8601String(),
        };

        final user = AppUser.fromJson(json);

        expect(user.uid, 'user-id-3');
        expect(user.displayName, 'Jane Smith');
        expect(user.email, 'jane@example.com');
        expect(user.photoURL, 'https://example.com/jane.jpg');
        expect(user.bandIds.length, 2);
        expect(user.bandIds[0], 'band-a');
        expect(user.bandIds[1], 'band-b');
        expect(user.createdAt, testDate);
      });

      test('handles null values with defaults', () {
        final json = {
          'uid': null,
          'displayName': null,
          'email': null,
          'photoURL': null,
          'bandIds': null,
          'createdAt': null,
        };

        final user = AppUser.fromJson(json);

        expect(user.uid, '');
        expect(user.displayName, isNull);
        expect(user.email, isNull);
        expect(user.photoURL, isNull);
        expect(user.bandIds, isEmpty);
        expect(user.createdAt, isNotNull);
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final user = AppUser.fromJson(json);

        expect(user.uid, '');
        expect(user.displayName, isNull);
        expect(user.email, isNull);
        expect(user.photoURL, isNull);
        expect(user.bandIds, isEmpty);
        expect(user.createdAt, isNotNull);
      });

      test('handles empty bandIds list', () {
        final json = {
          'uid': 'user-id-4',
          'bandIds': [],
          'createdAt': testDate.toIso8601String(),
        };

        final user = AppUser.fromJson(json);

        expect(user.bandIds, isEmpty);
      });

      test('parses bandIds correctly', () {
        final json = {
          'uid': 'user-id-5',
          'bandIds': [
            'band-001',
            'band-002',
            'band-003',
            'band-004',
            'band-005',
          ],
          'createdAt': testDate.toIso8601String(),
        };

        final user = AppUser.fromJson(json);

        expect(user.bandIds.length, 5);
        expect(user.bandIds[0], 'band-001');
        expect(user.bandIds[4], 'band-005');
      });

      test('handles user with only email', () {
        final json = {
          'uid': 'user-id-6',
          'email': 'onlyemail@example.com',
          'createdAt': testDate.toIso8601String(),
        };

        final user = AppUser.fromJson(json);

        expect(user.uid, 'user-id-6');
        expect(user.email, 'onlyemail@example.com');
        expect(user.displayName, isNull);
        expect(user.bandIds, isEmpty);
      });

      test('handles user with only displayName', () {
        final json = {
          'uid': 'user-id-7',
          'displayName': 'DisplayName Only',
          'createdAt': testDate.toIso8601String(),
        };

        final user = AppUser.fromJson(json);

        expect(user.uid, 'user-id-7');
        expect(user.displayName, 'DisplayName Only');
        expect(user.email, isNull);
      });
    });

    group('toJson', () {
      test('serializes complete user to JSON', () {
        final user = AppUser(
          uid: 'user-id-8',
          displayName: 'Serialize User',
          email: 'serialize@example.com',
          photoURL: 'https://example.com/serialize.jpg',
          bandIds: testBandIds,
          createdAt: testDate,
        );

        final json = user.toJson();

        expect(json['uid'], 'user-id-8');
        expect(json['displayName'], 'Serialize User');
        expect(json['email'], 'serialize@example.com');
        expect(json['photoURL'], 'https://example.com/serialize.jpg');
        expect(json['bandIds'], isA<List>());
        expect(json['bandIds'].length, 3);
        expect(json['createdAt'], testDate.toIso8601String());
      });

      test('serializes user with null values', () {
        final user = AppUser(
          uid: 'user-id-9',
          createdAt: testDate,
        );

        final json = user.toJson();

        expect(json['uid'], 'user-id-9');
        expect(json['displayName'], isNull);
        expect(json['email'], isNull);
        expect(json['photoURL'], isNull);
        expect(json['bandIds'], isA<List>());
        expect(json['bandIds'].length, 0);
      });

      test('toJson and fromJson are inverses', () {
        final originalUser = AppUser(
          uid: 'user-id-10',
          displayName: 'Inverse User',
          email: 'inverse@example.com',
          photoURL: 'https://example.com/inverse.jpg',
          bandIds: testBandIds,
          createdAt: testDate,
        );

        final json = originalUser.toJson();
        final restoredUser = AppUser.fromJson(json);

        expect(restoredUser.uid, originalUser.uid);
        expect(restoredUser.displayName, originalUser.displayName);
        expect(restoredUser.email, originalUser.email);
        expect(restoredUser.photoURL, originalUser.photoURL);
        expect(restoredUser.bandIds.length, originalUser.bandIds.length);
        expect(restoredUser.createdAt, originalUser.createdAt);
      });

      test('toJson preserves empty bandIds list', () {
        final user = AppUser(
          uid: 'user-id-11',
          bandIds: [],
          createdAt: testDate,
        );

        final json = user.toJson();

        expect(json['bandIds'], isA<List>());
        expect(json['bandIds'].length, 0);
      });
    });

    group('copyWith', () {
      test('returns a copy with all fields unchanged when no arguments', () {
        final originalUser = AppUser(
          uid: 'user-id-12',
          displayName: 'Original User',
          email: 'original@example.com',
          photoURL: 'https://example.com/original.jpg',
          bandIds: testBandIds,
          createdAt: testDate,
        );

        final copiedUser = originalUser.copyWith();

        expect(copiedUser.uid, originalUser.uid);
        expect(copiedUser.displayName, originalUser.displayName);
        expect(copiedUser.email, originalUser.email);
        expect(copiedUser.photoURL, originalUser.photoURL);
        expect(copiedUser.bandIds, originalUser.bandIds);
        expect(copiedUser.createdAt, originalUser.createdAt);
        expect(copiedUser, isNot(same(originalUser)));
      });

      test('updates displayName field', () {
        final originalUser = AppUser(
          uid: 'user-id-13',
          displayName: 'Old Name',
          createdAt: testDate,
        );

        final copiedUser = originalUser.copyWith(displayName: 'New Name');

        expect(copiedUser.displayName, 'New Name');
        expect(copiedUser.uid, 'user-id-13');
      });

      test('updates email field', () {
        final originalUser = AppUser(
          uid: 'user-id-14',
          email: 'old@example.com',
          createdAt: testDate,
        );

        final copiedUser = originalUser.copyWith(email: 'new@example.com');

        expect(copiedUser.email, 'new@example.com');
      });

      test('updates photoURL field', () {
        final originalUser = AppUser(
          uid: 'user-id-15',
          photoURL: 'https://example.com/old.jpg',
          createdAt: testDate,
        );

        final copiedUser = originalUser.copyWith(
          photoURL: 'https://example.com/new.jpg',
        );

        expect(copiedUser.photoURL, 'https://example.com/new.jpg');
      });

      test('updates bandIds field', () {
        final originalUser = AppUser(
          uid: 'user-id-16',
          bandIds: [],
          createdAt: testDate,
        );

        final newBandIds = ['new-band-1', 'new-band-2'];
        final copiedUser = originalUser.copyWith(bandIds: newBandIds);

        expect(copiedUser.bandIds, equals(newBandIds));
        expect(copiedUser.bandIds.length, 2);
      });

      test('updates multiple fields', () {
        final newDate = DateTime(2024, 8, 8);
        final originalUser = AppUser(
          uid: 'user-id-17',
          displayName: 'Old Name',
          email: 'old@example.com',
          photoURL: 'https://example.com/old.jpg',
          bandIds: ['old-band'],
          createdAt: testDate,
        );

        final copiedUser = originalUser.copyWith(
          displayName: 'New Name',
          email: 'new@example.com',
          photoURL: 'https://example.com/new.jpg',
          bandIds: ['new-band-1', 'new-band-2'],
          createdAt: newDate,
        );

        expect(copiedUser.displayName, 'New Name');
        expect(copiedUser.email, 'new@example.com');
        expect(copiedUser.photoURL, 'https://example.com/new.jpg');
        expect(copiedUser.bandIds.length, 2);
        expect(copiedUser.createdAt, newDate);
        expect(copiedUser.uid, 'user-id-17');
      });

      test('updates nullable fields to null', () {
        final originalUser = AppUser(
          uid: 'user-id-18',
          displayName: 'Some Name',
          email: 'some@example.com',
          photoURL: 'https://example.com/some.jpg',
          createdAt: testDate,
        );

        final copiedUser = originalUser.copyWith(
          displayName: null,
          email: null,
          photoURL: null,
        );

        expect(copiedUser.displayName, isNull);
        expect(copiedUser.email, isNull);
        expect(copiedUser.photoURL, isNull);
      });

      test('updates uid field', () {
        final originalUser = AppUser(
          uid: 'old-uid',
          createdAt: testDate,
        );

        final copiedUser = originalUser.copyWith(uid: 'new-uid');

        expect(copiedUser.uid, 'new-uid');
      });
    });

    group('Edge Cases', () {
      test('handles empty string uid', () {
        final user = AppUser(
          uid: '',
          createdAt: testDate,
        );

        expect(user.uid, '');
      });

      test('handles empty string displayName', () {
        final user = AppUser(
          uid: 'user-id-19',
          displayName: '',
          createdAt: testDate,
        );

        expect(user.displayName, '');
      });

      test('handles empty string email', () {
        final user = AppUser(
          uid: 'user-id-20',
          email: '',
          createdAt: testDate,
        );

        expect(user.email, '');
      });

      test('handles very long strings', () {
        final longString = 'z' * 5000;
        final user = AppUser(
          uid: longString,
          displayName: longString,
          email: '$longString@example.com',
          photoURL: 'https://example.com/$longString.jpg',
          createdAt: testDate,
        );

        expect(user.uid.length, 5000);
        expect(user.displayName!.length, 5000);
        expect(user.email!.length, greaterThan(5000));
      });

      test('handles special characters in displayName', () {
        final user = AppUser(
          uid: 'user-id-21',
          displayName: 'John "Johnny" Doe & Associates',
          email: 'john@example.com',
          createdAt: testDate,
        );

        expect(user.displayName, contains('"'));
        expect(user.displayName, contains('&'));
      });

      test('handles unicode characters', () {
        final user = AppUser(
          uid: 'user-id-22',
          displayName: 'ユーザー 山田太郎',
          email: '山田@example.com',
          photoURL: 'https://example.com/写真.jpg',
          createdAt: testDate,
        );

        expect(user.displayName, contains('ユーザー'));
        expect(user.displayName, contains('山田太郎'));
      });

      test('handles emoji in displayName', () {
        final user = AppUser(
          uid: 'user-id-23',
          displayName: 'Music Lover 🎵🎸🥁',
          email: 'music@example.com',
          createdAt: testDate,
        );

        expect(user.displayName, contains('🎵'));
        expect(user.displayName, contains('🎸'));
      });

      test('handles many bandIds', () {
        final manyBandIds = List.generate(100, (i) => 'band-$i');
        final user = AppUser(
          uid: 'user-id-24',
          bandIds: manyBandIds,
          createdAt: testDate,
        );

        expect(user.bandIds.length, 100);
        expect(user.bandIds.first, 'band-0');
        expect(user.bandIds.last, 'band-99');
      });

      test('handles email with special characters', () {
        final user = AppUser(
          uid: 'user-id-25',
          email: 'user+tag@example.co.uk',
          createdAt: testDate,
        );

        expect(user.email, contains('+'));
        expect(user.email, contains('.'));
      });

      test('handles photoURL with query parameters', () {
        final user = AppUser(
          uid: 'user-id-26',
          photoURL: 'https://example.com/photo.jpg?size=large&t=123456',
          createdAt: testDate,
        );

        expect(user.photoURL, contains('?'));
        expect(user.photoURL, contains('size='));
      });
    });

    group('Default Values', () {
      test('default bandIds is empty list', () {
        final user = AppUser(
          uid: 'user-id-27',
          createdAt: testDate,
        );

        expect(user.bandIds, equals([]));
      });

      test('fromJson default bandIds is empty list when null', () {
        final json = {
          'uid': 'user-id-28',
          'bandIds': null,
          'createdAt': testDate.toIso8601String(),
        };

        final user = AppUser.fromJson(json);

        expect(user.bandIds, equals([]));
      });

      test('fromJson handles missing createdAt with current time', () {
        final beforeParse = DateTime.now();
        final json = {
          'uid': 'user-id-29',
        };

        final user = AppUser.fromJson(json);
        final afterParse = DateTime.now();

        expect(user.createdAt, isNotNull);
        expect(user.createdAt.isAfter(beforeParse.subtract(const Duration(seconds: 1))), true);
        expect(user.createdAt.isBefore(afterParse.add(const Duration(seconds: 1))), true);
      });
    });

    group('Email Validation Patterns', () {
      test('handles various email formats', () {
        final emails = [
          'simple@example.com',
          'user.name@example.com',
          'user+tag@example.co.uk',
          'user_name@subdomain.example.com',
          'user123@example.org',
        ];

        for (final email in emails) {
          final user = AppUser(
            uid: 'user-email-test',
            email: email,
            createdAt: testDate,
          );

          expect(user.email, email, reason: 'Failed for email: $email');
        }
      });
    });

    group('Band Membership', () {
      test('user can belong to multiple bands', () {
        final user = AppUser(
          uid: 'user-id-30',
          bandIds: ['band-1', 'band-2', 'band-3', 'band-4', 'band-5'],
          createdAt: testDate,
        );

        expect(user.bandIds.length, 5);
        expect(user.bandIds.contains('band-1'), true);
        expect(user.bandIds.contains('band-5'), true);
      });

      test('user with no bands has empty list', () {
        final user = AppUser(
          uid: 'user-id-31',
          bandIds: [],
          createdAt: testDate,
        );

        expect(user.bandIds.isEmpty, true);
      });

      test('copyWith can add band to existing bands', () {
        final originalUser = AppUser(
          uid: 'user-id-32',
          bandIds: ['band-1', 'band-2'],
          createdAt: testDate,
        );

        final copiedUser = originalUser.copyWith(
          bandIds: [...originalUser.bandIds, 'band-3'],
        );

        expect(copiedUser.bandIds.length, 3);
        expect(copiedUser.bandIds.contains('band-3'), true);
      });
    });
  });
}
