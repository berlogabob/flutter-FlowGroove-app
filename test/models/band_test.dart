import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/band.dart';

void main() {
  group('BandMember Model', () {
    group('Constructor', () {
      test('creates BandMember with required fields', () {
        final member = BandMember(uid: 'user-123', role: BandMember.roleAdmin);

        expect(member.uid, 'user-123');
        expect(member.role, BandMember.roleAdmin);
        expect(member.displayName, isNull);
        expect(member.email, isNull);
      });

      test('creates BandMember with all fields', () {
        final member = BandMember(
          uid: 'user-456',
          role: BandMember.roleEditor,
          displayName: 'John Doe',
          email: 'john@example.com',
        );

        expect(member.uid, 'user-456');
        expect(member.role, BandMember.roleEditor);
        expect(member.displayName, 'John Doe');
        expect(member.email, 'john@example.com');
      });
    });

    group('Role Constants', () {
      test('roleAdmin constant is "admin"', () {
        expect(BandMember.roleAdmin, 'admin');
      });

      test('roleEditor constant is "editor"', () {
        expect(BandMember.roleEditor, 'editor');
      });

      test('roleViewer constant is "viewer"', () {
        expect(BandMember.roleViewer, 'viewer');
      });
    });

    group('fromJson', () {
      test('parses complete JSON data correctly', () {
        final json = {
          'uid': 'user-789',
          'role': 'editor',
          'displayName': 'Jane Smith',
          'email': 'jane@example.com',
        };

        final member = BandMember.fromJson(json);

        expect(member.uid, 'user-789');
        expect(member.role, 'editor');
        expect(member.displayName, 'Jane Smith');
        expect(member.email, 'jane@example.com');
      });

      test('handles null values with defaults', () {
        final json = {
          'uid': null,
          'role': null,
          'displayName': null,
          'email': null,
        };

        final member = BandMember.fromJson(json);

        expect(member.uid, '');
        expect(member.role, 'viewer'); // default role
        expect(member.displayName, isNull);
        expect(member.email, isNull);
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final member = BandMember.fromJson(json);

        expect(member.uid, '');
        expect(member.role, 'viewer'); // default role
      });

      test('handles missing role with default viewer', () {
        final json = {'uid': 'user-123'};

        final member = BandMember.fromJson(json);

        expect(member.uid, 'user-123');
        expect(member.role, 'viewer');
      });
    });

    group('toJson', () {
      test('serializes complete member to JSON', () {
        final member = BandMember(
          uid: 'user-111',
          role: BandMember.roleAdmin,
          displayName: 'Admin User',
          email: 'admin@example.com',
        );

        final json = member.toJson();

        expect(json['uid'], 'user-111');
        expect(json['role'], 'admin');
        expect(json['displayName'], 'Admin User');
        expect(json['email'], 'admin@example.com');
      });

      test('serializes member with null values', () {
        final member = BandMember(uid: 'user-222', role: BandMember.roleViewer);

        final json = member.toJson();

        expect(json['uid'], 'user-222');
        expect(json['role'], 'viewer');
        expect(json['displayName'], isNull);
        expect(json['email'], isNull);
      });

      test('toJson and fromJson are inverses', () {
        final originalMember = BandMember(
          uid: 'user-333',
          role: BandMember.roleEditor,
          displayName: 'Test User',
          email: 'test@example.com',
        );

        final json = originalMember.toJson();
        final restoredMember = BandMember.fromJson(json);

        expect(restoredMember.uid, originalMember.uid);
        expect(restoredMember.role, originalMember.role);
        expect(restoredMember.displayName, originalMember.displayName);
        expect(restoredMember.email, originalMember.email);
      });
    });
  });

  group('Band Model', () {
    // Test data
    final testDate = DateTime(2024, 3, 20, 14, 0, 0);
    final testMembers = [
      BandMember(
        uid: 'user-1',
        role: BandMember.roleAdmin,
        displayName: 'Admin',
      ),
      BandMember(
        uid: 'user-2',
        role: BandMember.roleEditor,
        displayName: 'Editor',
      ),
      BandMember(uid: 'user-3', role: BandMember.roleViewer),
    ];

    group('Constructor', () {
      test('creates Band with required fields', () {
        final band = Band(
          id: 'band-id-1',
          name: 'Test Band',
          createdBy: 'user-creator',
          createdAt: testDate,
        );

        expect(band.id, 'band-id-1');
        expect(band.name, 'Test Band');
        expect(band.createdBy, 'user-creator');
        expect(band.description, isNull);
        expect(band.members, isEmpty);
        expect(band.inviteCode, isNull);
        expect(band.createdAt, testDate);
      });

      test('creates Band with all optional fields', () {
        final band = Band(
          id: 'band-id-2',
          name: 'Complete Band',
          description: 'A complete test band',
          createdBy: 'user-creator-2',
          members: testMembers,
          inviteCode: 'INVITE123',
          createdAt: testDate,
        );

        expect(band.id, 'band-id-2');
        expect(band.name, 'Complete Band');
        expect(band.description, 'A complete test band');
        expect(band.createdBy, 'user-creator-2');
        expect(band.members.length, 3);
        expect(band.inviteCode, 'INVITE123');
        expect(band.createdAt, testDate);
      });
    });

    group('fromJson', () {
      test('parses complete JSON data correctly', () {
        final json = {
          'id': 'band-id-3',
          'name': 'JSON Band',
          'description': 'Band from JSON',
          'createdBy': 'user-json',
          'members': [
            {'uid': 'user-1', 'role': 'admin', 'displayName': 'Admin'},
            {'uid': 'user-2', 'role': 'editor'},
          ],
          'inviteCode': 'JSONCODE',
          'createdAt': testDate.toIso8601String(),
        };

        final band = Band.fromJson(json);

        expect(band.id, 'band-id-3');
        expect(band.name, 'JSON Band');
        expect(band.description, 'Band from JSON');
        expect(band.createdBy, 'user-json');
        expect(band.members.length, 2);
        expect(band.members[0].uid, 'user-1');
        expect(band.members[0].role, 'admin');
        expect(band.inviteCode, 'JSONCODE');
        expect(band.createdAt, testDate);
      });

      test('handles null values with defaults', () {
        final json = {
          'id': null,
          'name': null,
          'description': null,
          'createdBy': null,
          'members': null,
          'inviteCode': null,
          'createdAt': null,
        };

        final band = Band.fromJson(json);

        expect(band.id, '');
        expect(band.name, '');
        expect(band.description, isNull);
        expect(band.createdBy, '');
        expect(band.members, isEmpty);
        expect(band.inviteCode, isNull);
        expect(band.createdAt, isNotNull);
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final band = Band.fromJson(json);

        expect(band.id, '');
        expect(band.name, '');
        expect(band.createdBy, '');
        expect(band.members, isEmpty);
        expect(band.createdAt, isNotNull);
      });

      test('handles empty members list', () {
        final json = {
          'id': 'band-id-4',
          'name': 'Empty Band',
          'createdBy': 'user-empty',
          'members': [],
          'createdAt': testDate.toIso8601String(),
        };

        final band = Band.fromJson(json);

        expect(band.members, isEmpty);
      });

      test('parses members correctly', () {
        final json = {
          'id': 'band-id-5',
          'name': 'Band with Members',
          'createdBy': 'user-5',
          'members': [
            {
              'uid': 'user-a',
              'role': 'admin',
              'displayName': 'Admin A',
              'email': 'a@test.com',
            },
            {'uid': 'user-b', 'role': 'viewer'},
          ],
          'createdAt': testDate.toIso8601String(),
        };

        final band = Band.fromJson(json);

        expect(band.members.length, 2);
        expect(band.members[0].uid, 'user-a');
        expect(band.members[0].role, 'admin');
        expect(band.members[0].displayName, 'Admin A');
        expect(band.members[0].email, 'a@test.com');
        expect(band.members[1].uid, 'user-b');
        expect(band.members[1].role, 'viewer');
        expect(band.members[1].displayName, isNull);
      });
    });

    group('toJson', () {
      test('serializes complete band to JSON', () {
        final band = Band(
          id: 'band-id-6',
          name: 'Serialize Band',
          description: 'Band for serialization test',
          createdBy: 'user-serialize',
          members: testMembers,
          inviteCode: 'SERIALIZE123',
          createdAt: testDate,
        );

        final json = band.toJson();

        expect(json['id'], 'band-id-6');
        expect(json['name'], 'Serialize Band');
        expect(json['description'], 'Band for serialization test');
        expect(json['createdBy'], 'user-serialize');
        expect(json['members'], isA<List>());
        expect(json['members'].length, 3);
        expect(json['inviteCode'], 'SERIALIZE123');
        expect(json['createdAt'], testDate.toIso8601String());
      });

      test('serializes band with null values', () {
        final band = Band(
          id: 'band-id-7',
          name: 'Null Band',
          createdBy: 'user-null',
          createdAt: testDate,
        );

        final json = band.toJson();

        expect(json['id'], 'band-id-7');
        expect(json['name'], 'Null Band');
        expect(json['description'], isNull);
        expect(json['createdBy'], 'user-null');
        expect(json['members'], isA<List>());
        expect(json['members'].length, 0);
        expect(json['inviteCode'], isNull);
      });

      test('toJson and fromJson are inverses', () {
        final originalBand = Band(
          id: 'band-id-8',
          name: 'Inverse Band',
          description: 'Inverse test band',
          createdBy: 'user-inverse',
          members: testMembers,
          inviteCode: 'INVERSE456',
          createdAt: testDate,
        );

        final json = originalBand.toJson();
        final restoredBand = Band.fromJson(json);

        expect(restoredBand.id, originalBand.id);
        expect(restoredBand.name, originalBand.name);
        expect(restoredBand.description, originalBand.description);
        expect(restoredBand.createdBy, originalBand.createdBy);
        expect(restoredBand.members.length, originalBand.members.length);
        expect(restoredBand.inviteCode, originalBand.inviteCode);
        expect(restoredBand.createdAt, originalBand.createdAt);
      });
    });

    group('copyWith', () {
      test('returns a copy with all fields unchanged when no arguments', () {
        final originalBand = Band(
          id: 'band-id-9',
          name: 'Original Band',
          description: 'Original description',
          createdBy: 'user-original',
          members: testMembers,
          inviteCode: 'ORIGINAL',
          createdAt: testDate,
        );

        final copiedBand = originalBand.copyWith();

        expect(copiedBand.id, originalBand.id);
        expect(copiedBand.name, originalBand.name);
        expect(copiedBand.description, originalBand.description);
        expect(copiedBand.createdBy, originalBand.createdBy);
        expect(copiedBand.members, originalBand.members);
        expect(copiedBand.inviteCode, originalBand.inviteCode);
        expect(copiedBand.createdAt, originalBand.createdAt);
        expect(copiedBand, isNot(same(originalBand)));
      });

      test('updates name field', () {
        final originalBand = Band(
          id: 'band-id-10',
          name: 'Old Band Name',
          createdBy: 'user-10',
          createdAt: testDate,
        );

        final copiedBand = originalBand.copyWith(name: 'New Band Name');

        expect(copiedBand.name, 'New Band Name');
        expect(copiedBand.id, 'band-id-10');
      });

      test('updates description field', () {
        final originalBand = Band(
          id: 'band-id-11',
          name: 'Band 11',
          description: 'Old description',
          createdBy: 'user-11',
          createdAt: testDate,
        );

        final copiedBand = originalBand.copyWith(
          description: 'New description',
        );

        expect(copiedBand.description, 'New description');
      });

      test('updates members field', () {
        final originalBand = Band(
          id: 'band-id-12',
          name: 'Band 12',
          createdBy: 'user-12',
          members: [],
          createdAt: testDate,
        );

        final newMembers = [
          BandMember(uid: 'new-user', role: BandMember.roleAdmin),
        ];
        final copiedBand = originalBand.copyWith(members: newMembers);

        expect(copiedBand.members, equals(newMembers));
        expect(copiedBand.members.length, 1);
      });

      test('updates inviteCode field', () {
        final originalBand = Band(
          id: 'band-id-13',
          name: 'Band 13',
          createdBy: 'user-13',
          inviteCode: 'OLD_CODE',
          createdAt: testDate,
        );

        final copiedBand = originalBand.copyWith(inviteCode: 'NEW_CODE');

        expect(copiedBand.inviteCode, 'NEW_CODE');
      });

      test('updates multiple fields', () {
        final newDate = DateTime(2024, 12, 25);
        final originalBand = Band(
          id: 'band-id-14',
          name: 'Band 14',
          description: 'Description',
          createdBy: 'user-14',
          inviteCode: 'CODE',
          createdAt: testDate,
        );

        final copiedBand = originalBand.copyWith(
          name: 'Updated Band',
          description: 'Updated description',
          inviteCode: 'UPDATED',
          createdAt: newDate,
        );

        expect(copiedBand.name, 'Updated Band');
        expect(copiedBand.description, 'Updated description');
        expect(copiedBand.inviteCode, 'UPDATED');
        expect(copiedBand.createdAt, newDate);
        expect(copiedBand.createdBy, 'user-14');
      });

      test('updates nullable fields to null', () {
        final originalBand = Band(
          id: 'band-id-15',
          name: 'Band 15',
          description: 'Some description',
          createdBy: 'user-15',
          inviteCode: 'SOME_CODE',
          createdAt: testDate,
        );

        final copiedBand = originalBand.copyWith(
          description: null,
          inviteCode: null,
        );

        expect(copiedBand.description, isNull);
        expect(copiedBand.inviteCode, isNull);
      });
    });

    group('Edge Cases', () {
      test('handles empty string name', () {
        final band = Band(
          id: 'band-id-16',
          name: '',
          createdBy: 'user-16',
          createdAt: testDate,
        );

        expect(band.name, '');
      });

      test('handles very long strings', () {
        final longString = 'x' * 5000;
        final band = Band(
          id: 'band-id-17',
          name: longString,
          description: longString,
          createdBy: 'user-17',
          createdAt: testDate,
        );

        expect(band.name.length, 5000);
        expect(band.description!.length, 5000);
      });

      test('handles special characters in strings', () {
        final band = Band(
          id: 'band-id-18',
          name: 'Band & Orchestra "Ensemble"',
          description: 'Description with special: @#\$%^&*()',
          createdBy: 'user-18',
          createdAt: testDate,
        );

        expect(band.name, contains('&'));
        expect(band.description, contains('@#\$%^&*()'));
      });

      test('handles unicode characters', () {
        final band = Band(
          id: 'band-id-19',
          name: 'バンド 音楽',
          description: 'Описание with emoji 🎸🥁🎹',
          createdBy: 'user-19',
          createdAt: testDate,
        );

        expect(band.name, contains('バンド'));
        expect(band.description, contains('🎸'));
      });

      test('handles many members', () {
        final manyMembers = List.generate(
          50,
          (i) => BandMember(uid: 'user-$i', role: BandMember.roleViewer),
        );
        final band = Band(
          id: 'band-id-20',
          name: 'Big Band',
          createdBy: 'user-20',
          members: manyMembers,
          createdAt: testDate,
        );

        expect(band.members.length, 50);
        expect(band.members.first.uid, 'user-0');
        expect(band.members.last.uid, 'user-49');
      });
    });

    group('Default Values', () {
      test('default members is empty list', () {
        final band = Band(
          id: 'band-id-21',
          name: 'Default Band',
          createdBy: 'user-21',
          createdAt: testDate,
        );

        expect(band.members, equals([]));
      });

      test('fromJson default members is empty list when null', () {
        final json = {
          'id': 'band-id-22',
          'name': 'Default Members Band',
          'createdBy': 'user-22',
          'members': null,
          'createdAt': testDate.toIso8601String(),
        };

        final band = Band.fromJson(json);

        expect(band.members, equals([]));
      });

      test('fromJson default role is viewer when null', () {
        final json = {'uid': 'user-23', 'role': null};

        final member = BandMember.fromJson(json);

        expect(member.role, 'viewer');
      });
    });
  });
}
