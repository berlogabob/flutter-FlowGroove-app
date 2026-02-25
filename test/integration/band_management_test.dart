/// Band Management Flow Integration Tests
///
/// End-to-end tests for band CRUD operations, member management,
/// and band-related user flows.
///
/// Test ID: INT-BAND-01
/// Priority: P0 🔴
/// Estimated Time: 2.5 hours
/// Actual Time: 2 hours
///
/// To run: flutter test test/integration/band_management_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/user.dart';
import 'package:flutter_repsync_app/widgets/band_card.dart';

import '../helpers/mocks.mocks.dart';
import '../helpers/test_helpers.dart';
import '../helpers/integration_test_helpers.dart';

void main() {
  group('Band Management Flow Integration Tests - INT-BAND-01', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();

      // Setup default auth mocks
      when(mockUser.uid).thenReturn('test-user-id');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.displayName).thenReturn('Test User');
      when(mockAuth.currentUser).thenReturn(mockUser);
    });

    // =========================================================================
    // BAND MODEL TESTS
    // =========================================================================
    group('Band Model Core Tests', () {
      testWidgets('INT-BAND-01.1: Band model creates with valid data',
          (WidgetTester tester) async {
        // Arrange & Act: Create band model
        final band = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [
            BandMember(uid: 'test-user-id', role: BandMember.roleAdmin),
          ],
          createdAt: DateTime.now(),
        );

        // Assert: Band properties set correctly
        expect(band.name, equals('Test Band'));
        expect(band.createdBy, equals('test-user-id'));
        expect(band.members.length, equals(1));
        expect(band.adminUids, contains('test-user-id'));
      });

      testWidgets('INT-BAND-01.2: Band model generates unique invite code',
          (WidgetTester tester) async {
        // Arrange & Act: Generate multiple invite codes
        final code1 = Band.generateUniqueInviteCode();
        final code2 = Band.generateUniqueInviteCode();
        final code3 = Band.generateUniqueInviteCode();

        // Assert: Codes are unique and 6 characters
        expect(code1.length, equals(6));
        expect(code2.length, equals(6));
        expect(code3.length, equals(6));
        expect(code1, isNot(equals(code2)));
        expect(code2, isNot(equals(code3)));
        expect(code1, isNot(equals(code3)));
      });

      testWidgets('INT-BAND-01.3: Band invite code is alphanumeric',
          (WidgetTester tester) async {
        // Arrange & Act
        final code = Band.generateUniqueInviteCode();

        // Assert: Code contains only uppercase letters and digits
        expect(code, matches(r'^[A-Z0-9]{6}$'));
      });

      testWidgets('INT-BAND-01.4: Band member roles are correct',
          (WidgetTester tester) async {
        // Arrange
        final band = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [
            BandMember(uid: 'admin-1', role: BandMember.roleAdmin),
            BandMember(uid: 'editor-1', role: BandMember.roleEditor),
            BandMember(uid: 'viewer-1', role: BandMember.roleViewer),
          ],
          createdAt: DateTime.now(),
        );

        // Assert: Role constants and derived UIDs
        expect(BandMember.roleAdmin, equals('admin'));
        expect(BandMember.roleEditor, equals('editor'));
        expect(BandMember.roleViewer, equals('viewer'));
        expect(band.adminUids, contains('admin-1'));
        expect(band.editorUids, contains('editor-1'));
        expect(band.memberUids, contains('admin-1'));
        expect(band.memberUids, contains('editor-1'));
        expect(band.memberUids, contains('viewer-1'));
      });

      testWidgets('INT-BAND-01.5: Band copyWith updates name',
          (WidgetTester tester) async {
        // Arrange
        final originalBand = Band(
          id: const Uuid().v4(),
          name: 'Original Band',
          createdBy: 'test-user-id',
          members: [],
          createdAt: DateTime.now(),
        );

        // Act: Update name
        final updatedBand = originalBand.copyWith(name: 'Updated Band');

        // Assert
        expect(updatedBand.name, equals('Updated Band'));
        expect(updatedBand.id, equals(originalBand.id));
        expect(updatedBand.createdBy, equals(originalBand.createdBy));
      });

      testWidgets('INT-BAND-01.6: Band copyWith updates description',
          (WidgetTester tester) async {
        // Arrange
        final originalBand = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [],
          description: 'Original description',
          createdAt: DateTime.now(),
        );

        // Act
        final updatedBand = originalBand.copyWith(description: 'New description');

        // Assert
        expect(updatedBand.description, equals('New description'));
        expect(updatedBand.name, equals(originalBand.name));
      });

      testWidgets('INT-BAND-01.7: Band copyWith adds members',
          (WidgetTester tester) async {
        // Arrange
        final originalBand = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [
            BandMember(uid: 'user-1', role: BandMember.roleAdmin),
          ],
          createdAt: DateTime.now(),
        );

        // Act: Add new member
        final newMembers = [
          ...originalBand.members,
          BandMember(uid: 'user-2', role: BandMember.roleEditor),
        ];
        final updatedBand = originalBand.copyWith(members: newMembers);

        // Assert
        expect(updatedBand.members.length, equals(2));
        expect(updatedBand.memberUids.length, equals(2));
        expect(updatedBand.editorUids, contains('user-2'));
      });

      testWidgets('INT-BAND-01.8: Band toJson and fromJson roundtrip',
          (WidgetTester tester) async {
        // Arrange
        final originalBand = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [
            BandMember(
              uid: 'user-1',
              role: BandMember.roleAdmin,
              displayName: 'Test User',
              email: 'test@example.com',
            ),
          ],
          description: 'Test description',
          inviteCode: 'ABC123',
          createdAt: DateTime(2024, 1, 1, 12, 0),
        );

        // Act: Serialize and deserialize
        final json = originalBand.toJson();
        final deserializedBand = Band.fromJson(json);

        // Assert
        expect(deserializedBand.id, equals(originalBand.id));
        expect(deserializedBand.name, equals(originalBand.name));
        expect(deserializedBand.description, equals(originalBand.description));
        expect(deserializedBand.createdBy, equals(originalBand.createdBy));
        expect(deserializedBand.members.length, equals(1));
        expect(deserializedBand.inviteCode, equals(originalBand.inviteCode));
      });

      testWidgets('INT-BAND-01.9: Band with null description handled',
          (WidgetTester tester) async {
        // Arrange & Act
        final band = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [],
          description: null,
          createdAt: DateTime.now(),
        );

        // Assert
        expect(band.description, isNull);
        expect(band.name, equals('Test Band'));
      });

      testWidgets('INT-BAND-01.10: Band member with email',
          (WidgetTester tester) async {
        // Arrange
        final member = BandMember(
          uid: 'user-1',
          role: BandMember.roleAdmin,
          displayName: 'Test User',
          email: 'test@example.com',
        );

        // Assert
        expect(member.uid, equals('user-1'));
        expect(member.email, equals('test@example.com'));
        expect(member.displayName, equals('Test User'));
        expect(member.role, equals(BandMember.roleAdmin));
      });

      testWidgets('INT-BAND-01.11: Band member toJson roundtrip',
          (WidgetTester tester) async {
        // Arrange
        final originalMember = BandMember(
          uid: 'user-1',
          role: BandMember.roleEditor,
          displayName: 'Editor User',
          email: 'editor@example.com',
        );

        // Act
        final json = originalMember.toJson();
        final deserializedMember = BandMember.fromJson(json);

        // Assert
        expect(deserializedMember.uid, equals(originalMember.uid));
        expect(deserializedMember.role, equals(originalMember.role));
        expect(deserializedMember.displayName, equals(originalMember.displayName));
        expect(deserializedMember.email, equals(originalMember.email));
      });
    });

    // =========================================================================
    // MEMBER MANAGEMENT TESTS
    // =========================================================================
    group('Member Management Tests', () {
      testWidgets('INT-BAND-01.12: Add member to band',
          (WidgetTester tester) async {
        // Arrange
        final band = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [
            BandMember(uid: 'test-user-id', role: BandMember.roleAdmin),
          ],
          createdAt: DateTime.now(),
        );

        // Act: Add new member
        final newMember = BandMember(
          uid: 'new-user-id',
          role: BandMember.roleViewer,
          email: 'new@example.com',
        );
        final updatedMembers = [...band.members, newMember];
        final updatedBand = band.copyWith(members: updatedMembers);

        // Assert
        expect(updatedBand.members.length, equals(2));
        expect(updatedBand.memberUids, contains('new-user-id'));
      });

      testWidgets('INT-BAND-01.13: Remove member from band',
          (WidgetTester tester) async {
        // Arrange
        final band = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [
            BandMember(uid: 'test-user-id', role: BandMember.roleAdmin),
            BandMember(uid: 'user-to-remove', role: BandMember.roleViewer),
          ],
          createdAt: DateTime.now(),
        );

        // Act: Remove member
        final updatedMembers = band.members
            .where((m) => m.uid != 'user-to-remove')
            .toList();
        final updatedBand = band.copyWith(members: updatedMembers);

        // Assert
        expect(updatedBand.members.length, equals(1));
        expect(updatedBand.memberUids, isNot(contains('user-to-remove')));
      });

      testWidgets('INT-BAND-01.14: Change member role',
          (WidgetTester tester) async {
        // Arrange
        final band = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [
            BandMember(uid: 'user-1', role: BandMember.roleViewer),
          ],
          createdAt: DateTime.now(),
        );

        // Act: Change role from viewer to editor
        final updatedMembers = band.members.map((m) {
          if (m.uid == 'user-1') {
            return BandMember(uid: m.uid, role: BandMember.roleEditor);
          }
          return m;
        }).toList();
        final updatedBand = band.copyWith(members: updatedMembers);

        // Assert
        expect(updatedBand.members.first.role, equals(BandMember.roleEditor));
        expect(updatedBand.editorUids, contains('user-1'));
        expect(updatedBand.adminUids, isEmpty);
      });

      testWidgets('INT-BAND-01.15: Multiple admins supported',
          (WidgetTester tester) async {
        // Arrange
        final band = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [
            BandMember(uid: 'admin-1', role: BandMember.roleAdmin),
            BandMember(uid: 'admin-2', role: BandMember.roleAdmin),
            BandMember(uid: 'viewer-1', role: BandMember.roleViewer),
          ],
          createdAt: DateTime.now(),
        );

        // Assert
        expect(band.adminUids.length, equals(2));
        expect(band.adminUids, contains('admin-1'));
        expect(band.adminUids, contains('admin-2'));
      });

      testWidgets('INT-BAND-01.16: Band with many members',
          (WidgetTester tester) async {
        // Arrange & Act: Create band with 10 members
        final members = List.generate(
          10,
          (i) => BandMember(
            uid: 'user-$i',
            role: i < 2 ? BandMember.roleAdmin : BandMember.roleViewer,
          ),
        );

        final band = Band(
          id: const Uuid().v4(),
          name: 'Large Band',
          createdBy: 'user-0',
          members: members,
          createdAt: DateTime.now(),
        );

        // Assert
        expect(band.members.length, equals(10));
        expect(band.adminUids.length, equals(2));
        expect(band.memberUids.length, equals(10));
      });
    });

    // =========================================================================
    // EDGE CASES AND ERROR HANDLING
    // =========================================================================
    group('Edge Cases and Error Handling', () {
      testWidgets('INT-BAND-01.17: Band name with special characters',
          (WidgetTester tester) async {
        // Arrange
        final band = Band(
          id: const Uuid().v4(),
          name: 'Test Band @ # \$!',
          createdBy: 'test-user-id',
          members: [],
          createdAt: DateTime.now(),
        );

        // Assert: Special characters handled
        expect(band.name, equals('Test Band @ # \$!'));
      });

      testWidgets('INT-BAND-01.18: Very long band name',
          (WidgetTester tester) async {
        // Arrange
        final longName = 'A' * 100;
        final band = Band(
          id: const Uuid().v4(),
          name: longName,
          createdBy: 'test-user-id',
          members: [],
          createdAt: DateTime.now(),
        );

        // Assert: Long name stored
        expect(band.name.length, equals(100));
      });

      testWidgets('INT-BAND-01.19: Duplicate band names allowed',
          (WidgetTester tester) async {
        // Arrange: Multiple bands with same name
        final band1 = Band(
          id: const Uuid().v4(),
          name: 'Duplicate Name',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime.now(),
        );

        final band2 = Band(
          id: const Uuid().v4(),
          name: 'Duplicate Name',
          createdBy: 'user-2',
          members: [],
          createdAt: DateTime.now(),
        );

        // Assert: Different IDs allow same name
        expect(band1.name, equals(band2.name));
        expect(band1.id, isNot(equals(band2.id)));
      });

      testWidgets('INT-BAND-01.20: Empty band members list',
          (WidgetTester tester) async {
        // Arrange
        final band = Band(
          id: const Uuid().v4(),
          name: 'Empty Band',
          createdBy: 'test-user-id',
          members: [],
          createdAt: DateTime.now(),
        );

        // Assert
        expect(band.members.isEmpty, isTrue);
        expect(band.adminUids.isEmpty, isTrue);
        expect(band.editorUids.isEmpty, isTrue);
        expect(band.memberUids.isEmpty, isTrue);
      });

      testWidgets('INT-BAND-01.21: Band JSON with default values',
          (WidgetTester tester) async {
        // Arrange: Minimal band data
        final json = {
          'id': 'test-id',
          'name': 'Test Band',
          'createdBy': 'user-1',
          'createdAt': DateTime.now().toIso8601String(),
        };

        // Act
        final band = Band.fromJson(json);

        // Assert: Defaults applied
        expect(band.id, equals('test-id'));
        expect(band.name, equals('Test Band'));
        expect(band.members, isEmpty);
        expect(band.description, isNull);
        expect(band.inviteCode, isNull);
      });

      testWidgets('INT-BAND-01.22: Band member with minimal data',
          (WidgetTester tester) async {
        // Arrange & Act
        final member = BandMember(
          uid: 'user-1',
          role: BandMember.roleViewer,
        );

        // Assert
        expect(member.uid, equals('user-1'));
        expect(member.role, equals(BandMember.roleViewer));
        expect(member.displayName, isNull);
        expect(member.email, isNull);
      });

      testWidgets('INT-BAND-01.23: Invite code uniqueness',
          (WidgetTester tester) async {
        // Arrange & Act: Generate 100 codes
        final codes = Set<String>();
        for (int i = 0; i < 100; i++) {
          codes.add(Band.generateUniqueInviteCode());
        }

        // Assert: All codes unique
        expect(codes.length, equals(100));
      });

      testWidgets('INT-BAND-01.24: Band createdAt timestamp preserved',
          (WidgetTester tester) async {
        // Arrange
        final createdAt = DateTime(2024, 6, 15, 10, 30, 0);
        final band = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [],
          createdAt: createdAt,
        );

        // Assert
        expect(band.createdAt.year, equals(2024));
        expect(band.createdAt.month, equals(6));
        expect(band.createdAt.day, equals(15));
      });

      testWidgets('INT-BAND-01.25: Band copyWith preserves createdAt',
          (WidgetTester tester) async {
        // Arrange
        final originalCreatedAt = DateTime(2024, 1, 1);
        final originalBand = Band(
          id: const Uuid().v4(),
          name: 'Test Band',
          createdBy: 'test-user-id',
          members: [],
          createdAt: originalCreatedAt,
        );

        // Act: Update other fields
        final updatedBand = originalBand.copyWith(name: 'Updated Name');

        // Assert: createdAt preserved
        expect(updatedBand.createdAt, equals(originalCreatedAt));
        expect(updatedBand.name, equals('Updated Name'));
      });

      testWidgets('INT-BAND-01.26: Band with all optional fields',
          (WidgetTester tester) async {
        // Arrange
        final band = Band(
          id: const Uuid().v4(),
          name: 'Complete Band',
          description: 'Full description',
          createdBy: 'test-user-id',
          members: [
            BandMember(
              uid: 'user-1',
              role: BandMember.roleAdmin,
              displayName: 'Admin User',
              email: 'admin@example.com',
            ),
          ],
          inviteCode: 'XYZ789',
          createdAt: DateTime.now(),
        );

        // Assert: All fields present
        expect(band.id.isNotEmpty, isTrue);
        expect(band.name, equals('Complete Band'));
        expect(band.description, equals('Full description'));
        expect(band.inviteCode, equals('XYZ789'));
        expect(band.members.length, equals(1));
        expect(band.adminUids.length, equals(1));
      });
    });

    // =========================================================================
    // BAND CARD WIDGET TESTS
    // =========================================================================
    group('Band Card Widget Tests', () {
      testWidgets('INT-BAND-01.27: Band card displays band name',
          (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BandCard(
                id: 'test-id',
                name: 'Test Band',
                memberCount: 3,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Test Band'), findsOneWidget);
      });

      testWidgets('INT-BAND-01.28: Band card displays member count',
          (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BandCard(
                id: 'test-id',
                name: 'Test Band',
                memberCount: 5,
                description: 'A great band',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Member count shown
        expect(find.text('Test Band'), findsOneWidget);
        expect(find.textContaining('5'), findsOneWidget);
      });

      testWidgets('INT-BAND-01.29: Band card is tappable',
          (WidgetTester tester) async {
        // Arrange
        bool wasTapped = false;

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BandCard(
                id: 'test-id',
                name: 'Test Band',
                memberCount: 3,
                onTap: () => wasTapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test Band'));
        await tester.pump();

        // Assert
        expect(wasTapped, isTrue);
      });

      testWidgets('INT-BAND-01.30: Band card with description',
          (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BandCard(
                id: 'test-id',
                name: 'Test Band',
                memberCount: 3,
                description: 'This is a test band description',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Test Band'), findsOneWidget);
        expect(find.textContaining('description'), findsOneWidget);
      });
    });
  });
}
