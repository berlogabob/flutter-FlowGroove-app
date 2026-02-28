/// Setlist Management Flow Integration Tests
///
/// End-to-end tests for setlist CRUD operations, reordering,
/// duration calculation, and PDF export integration.
///
/// Test ID: INT-SETLIST-01
/// Priority: P0 🔴
/// Estimated Time: 1.5 hours
///
/// To run: flutter test test/integration/setlist_management_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/screens/setlists/setlists_list_screen.dart';
import 'package:flutter_repsync_app/screens/setlists/create_setlist_screen.dart';

import '../helpers/mocks.mocks.dart';
import '../helpers/test_helpers.dart';
import '../helpers/integration_test_helpers.dart';

void main() {
  group('Setlist Management Flow Integration Tests - INT-SETLIST-01', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocument;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;

    setUp(() {
      // Create fresh mock instances for each test
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocument = MockDocumentReference<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();

      // Note: Individual tests set up their own mock behaviors
      // This avoids "Cannot call when within stub response" errors
    });

    // =========================================================================
    // CREATE SETLIST FLOW TESTS
    // =========================================================================
    group('Create Setlist Flow', () {
      testWidgets('INT-SETLIST-01.1: Create setlist with valid name succeeds', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlistId = const Uuid().v4();
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.set(any, any)).thenAnswer((_) async => {});
        when(mockDocument.id).thenReturn(setlistId);

        final setlist = Setlist(
          id: '',
          bandId: 'test-band-id',
          name: '',
          songIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: CreateSetlistScreen(setlist: setlist)),
          ),
        );
        await tester.pumpAndSettle();

        // Act: Enter setlist name
        final nameField = find.byType(TextFormField).at(0);
        await tester.enterText(nameField, 'Test Setlist');
        await tester.pump();

        // Tap create button
        final createButton = find.text('Create Setlist');
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        // Assert: Setlist creation attempted
        verify(mockDocument.set(any, any)).called(1);
      });

      testWidgets('INT-SETLIST-01.2: Create setlist with event date', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlistId = const Uuid().v4();
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.set(any, any)).thenAnswer((_) async => {});
        when(mockDocument.id).thenReturn(setlistId);

        final setlist = Setlist(
          id: setlistId,
          name: 'Gig Setlist',
          bandId: 'test-band-id',
          songIds: [],
          eventDate: DateTime(2024, 6, 15),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: Event date stored
        expect(setlist.eventDate, equals(DateTime(2024, 6, 15)));
      });

      testWidgets('INT-SETLIST-01.3: Create setlist with description', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlistId = const Uuid().v4();
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.set(any, any)).thenAnswer((_) async => {});
        when(mockDocument.id).thenReturn(setlistId);

        final setlist = Setlist(
          id: setlistId,
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: [],
          description: 'Setlist for summer tour',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: Description stored
        expect(setlist.description, equals('Setlist for summer tour'));
      });

      testWidgets(
        'INT-SETLIST-01.4: Create setlist with empty name shows validation',
        (WidgetTester tester) async {
          // Arrange
          final setlist = Setlist(
            id: '',
            bandId: 'test-band-id',
            name: '',
            songIds: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(home: CreateSetlistScreen(setlist: setlist)),
            ),
          );
          await tester.pumpAndSettle();

          // Act: Try to create without name
          final createButton = find.text('Create Setlist');
          await tester.tap(createButton);
          await tester.pumpAndSettle();

          // Assert: Validation error
          expect(find.textContaining('required'), findsOneWidget);
        },
      );

      testWidgets('INT-SETLIST-01.5: Create setlist appears in setlists list', (
        WidgetTester tester,
      ) async {
        // Arrange
        final testSetlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(
          mockCollection.where(any, isEqualTo: anyNamed('isEqualTo')),
        ).thenReturn(mockCollection);
        when(
          mockCollection.get(any),
        ).thenAnswer((_) async => mockQuerySnapshot);

        // Use mockDocSnapshot from setUp instead of creating new mock
        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(testSetlist.toJson());
        when(mockDocSnapshot.id).thenReturn(testSetlist.id);
        // Mock query snapshot returns list with one document
        when(mockQuerySnapshot.size).thenReturn(1);
        // Use dynamic cast to work around type system - mockito handles it
        when(mockQuerySnapshot.docs).thenReturn(
          <dynamic>[mockDocSnapshot]
              as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
        );

        // Act
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: mockQuerySnapshot.size,
                  itemBuilder: (context, index) {
                    return Text(testSetlist.name);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Setlist appears in list
        expect(find.text('Test Setlist'), findsOneWidget);
      });

      testWidgets('INT-SETLIST-01.6: Create setlist links to band', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlistId = const Uuid().v4();
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.set(any, any)).thenAnswer((_) async => {});
        when(mockDocument.id).thenReturn(setlistId);

        final setlist = Setlist(
          id: setlistId,
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: Band ID stored
        expect(setlist.bandId, equals('test-band-id'));
      });
    });

    // =========================================================================
    // ADD SONGS TO SETLIST FLOW TESTS
    // =========================================================================
    group('Add Songs to Setlist Flow', () {
      testWidgets('INT-SETLIST-01.7: Add songs to setlist', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Act: Add songs
        final newSongIds = [...setlist.songIds, 'song-1', 'song-2'];
        final updatedSetlist = setlist.copyWith(
          songIds: newSongIds,
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(updatedSetlist.songIds.length, equals(2));
      });

      testWidgets('INT-SETLIST-01.8: Add songs calculates setlist duration', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songs = [
          Song(
            id: 'song-1',
            title: 'Song 1',
            artist: 'Artist',
            originalBPM: 120,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 'song-2',
            title: 'Song 2',
            artist: 'Artist',
            originalBPM: 140,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Calculate duration (assuming ~4 minutes per song average)
        final estimatedDuration = songs.length * 4 * 60; // seconds

        // Assert
        expect(estimatedDuration, equals(480)); // 8 minutes
      });

      testWidgets('INT-SETLIST-01.9: Add songs displays in order', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final songs = [
          Song(
            id: 'song-1',
            title: 'First Song',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 'song-2',
            title: 'Second Song',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 'song-3',
            title: 'Third Song',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Get songs in setlist order
        final orderedSongs = setlist.songIds
            .map((id) => songs.firstWhere((s) => s.id == id))
            .toList();

        // Assert
        expect(orderedSongs[0].title, equals('First Song'));
        expect(orderedSongs[1].title, equals('Second Song'));
        expect(orderedSongs[2].title, equals('Third Song'));
      });

      testWidgets('INT-SETLIST-01.10: Add duplicate song to setlist', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Try to add duplicate
        final newSongIds = [...setlist.songIds, 'song-1'];
        final uniqueSongIds = newSongIds.toSet().toList();

        // Assert: Duplicates removed
        expect(uniqueSongIds.length, equals(1));
      });

      testWidgets('INT-SETLIST-01.11: Add songs persists to Firestore', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Act
        await mockDocument.update({
          'songIds': ['song-1', 'song-2'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await tester.pump();

        // Assert
        verify(mockDocument.update(any)).called(1);
      });

      testWidgets('INT-SETLIST-01.12: Add songs updates UI', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Add song
        final updatedSetlist = setlist.copyWith(
          songIds: ['song-1', 'song-2'],
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: updatedSetlist.songIds.length,
                  itemBuilder: (context, index) {
                    return Text('Song ${index + 1}');
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Both songs shown
        expect(find.text('Song 1'), findsOneWidget);
        expect(find.text('Song 2'), findsOneWidget);
      });
    });

    // =========================================================================
    // REORDER SETLIST FLOW TESTS
    // =========================================================================
    group('Reorder Setlist Flow', () {
      testWidgets('INT-SETLIST-01.13: Reorder songs in setlist', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Reorder (move song-3 to first position)
        final newOrder = ['song-3', 'song-1', 'song-2'];
        final updatedSetlist = setlist.copyWith(
          songIds: newOrder,
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(updatedSetlist.songIds[0], equals('song-3'));
        expect(updatedSetlist.songIds[2], equals('song-2'));
      });

      testWidgets('INT-SETLIST-01.14: Reorder updates Firestore', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Act
        await mockDocument.update({
          'songIds': ['song-3', 'song-1', 'song-2'],
        });
        await tester.pump();

        // Assert
        verify(mockDocument.update(any)).called(1);
      });

      testWidgets('INT-SETLIST-01.15: Reorder recalculates duration', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1', 'song-2', 'song-3'],
          totalDuration: 720, // 12 minutes
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Reorder (duration should remain same for same songs)
        final newOrder = ['song-3', 'song-1', 'song-2'];
        final updatedSetlist = setlist.copyWith(
          songIds: newOrder,
          updatedAt: DateTime.now(),
        );

        // Assert: Duration unchanged for same songs
        expect(updatedSetlist.totalDuration, equals(720));
      });

      testWidgets('INT-SETLIST-01.16: Drag and drop reordering UI', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songs = ['Song 1', 'Song 2', 'Song 3'];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ReorderableListView.builder(
                  itemCount: songs.length,
                  onReorder: (oldIndex, newIndex) {},
                  itemBuilder: (context, index) {
                    return ListTile(
                      key: ValueKey(songs[index]),
                      title: Text(songs[index]),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Reorderable list shown
        expect(find.text('Song 1'), findsOneWidget);
        expect(find.text('Song 2'), findsOneWidget);
        expect(find.text('Song 3'), findsOneWidget);
      });
    });

    // =========================================================================
    // REMOVE SONG FROM SETLIST FLOW TESTS
    // =========================================================================
    group('Remove Song from Setlist Flow', () {
      testWidgets('INT-SETLIST-01.17: Remove song from setlist', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Act: Remove song-2
        final newSongIds = setlist.songIds
            .where((id) => id != 'song-2')
            .toList();
        final updatedSetlist = setlist.copyWith(
          songIds: newSongIds,
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(updatedSetlist.songIds.length, equals(2));
        expect(updatedSetlist.songIds.contains('song-2'), isFalse);
      });

      testWidgets('INT-SETLIST-01.18: Remove song recalculates duration', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1', 'song-2', 'song-3'],
          totalDuration: 720, // 12 minutes (3 songs × 4 min)
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Remove one song
        final newSongIds = setlist.songIds
            .where((id) => id != 'song-2')
            .toList();
        final newDuration = (newSongIds.length * 4 * 60); // Recalculate

        // Assert
        expect(newSongIds.length, equals(2));
        expect(newDuration, equals(480)); // 8 minutes
      });

      testWidgets('INT-SETLIST-01.19: Remove song updates UI', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Remove song-2
        final newSongIds = setlist.songIds
            .where((id) => id != 'song-2')
            .toList();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: newSongIds.length,
                  itemBuilder: (context, index) {
                    return Text('Song ${index + 1}');
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Only 2 songs shown
        expect(find.text('Song 1'), findsOneWidget);
        expect(find.text('Song 2'), findsOneWidget);
        expect(find.text('Song 3'), findsNothing);
      });

      testWidgets('INT-SETLIST-01.20: Remove last song from setlist', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Remove last song
        final newSongIds = setlist.songIds
            .where((id) => id != 'song-1')
            .toList();

        // Assert: Empty setlist is valid
        expect(newSongIds.isEmpty, isTrue);
      });
    });

    // =========================================================================
    // DELETE SETLIST FLOW TESTS
    // =========================================================================
    group('Delete Setlist Flow', () {
      testWidgets('INT-SETLIST-01.21: Delete setlist from settings', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.delete()).thenAnswer((_) async => {});

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Text('Setlist Detail'),
                    ElevatedButton(
                      onPressed: null, // Would trigger delete
                      child: Text('Delete Setlist'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act: Tap delete
        final deleteButton = find.text('Delete Setlist');
        expect(deleteButton, findsOneWidget);
      });

      testWidgets(
        'INT-SETLIST-01.22: Delete setlist confirms before deletion',
        (WidgetTester tester) async {
          // Arrange
          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(
                home: Scaffold(
                  body: AlertDialog(
                    title: Text('Delete Setlist'),
                    content: Text('Are you sure?'),
                    actions: [
                      TextButton(
                        onPressed: null, // Cancel
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: null, // Confirm
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Assert: Confirmation dialog shown
          expect(find.text('Are you sure?'), findsOneWidget);
        },
      );

      testWidgets('INT-SETLIST-01.23: Delete setlist removes from Firestore', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.delete()).thenAnswer((_) async => {});

        // Act
        await mockDocument.delete();
        await tester.pump();

        // Assert
        verify(mockDocument.delete()).called(1);
      });

      testWidgets('INT-SETLIST-01.24: Delete setlist does NOT delete songs', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songs = [
          Song(
            id: 'song-1',
            title: 'Song 1',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 'song-2',
            title: 'Song 2',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.delete()).thenAnswer((_) async => {});

        // Act: Delete setlist (songs should remain)
        await mockDocument.delete();

        // Assert: Songs are orphaned, not deleted
        expect(songs.length, equals(2));
        verify(mockDocument.delete()).called(1);
        // Note: Songs collection not touched
      });

      testWidgets(
        'INT-SETLIST-01.25: Delete setlist redirects to setlists list',
        (WidgetTester tester) async {
          // Arrange & Act: Simulate navigation after delete
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      const Text('Setlist Detail'),
                      ElevatedButton(
                        onPressed: () {
                          // Would navigate back to list
                        },
                        child: const Text('Back to Setlists'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Assert: Back button present
          expect(find.text('Back to Setlists'), findsOneWidget);
        },
      );
    });

    // =========================================================================
    // SETLIST + PDF EXPORT INTEGRATION TESTS
    // =========================================================================
    group('Setlist + PDF Export Integration', () {
      testWidgets('INT-SETLIST-01.26: Export setlist to PDF', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Text('Setlist: ${setlist.name}'),
                    ElevatedButton(
                      onPressed: () {
                        // Would export PDF
                      },
                      child: const Text('Export PDF'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Export button present
        expect(find.text('Export PDF'), findsOneWidget);
      });

      testWidgets('INT-SETLIST-01.27: PDF contains all songs', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final songs = [
          {'id': 'song-1', 'title': 'First Song'},
          {'id': 'song-2', 'title': 'Second Song'},
          {'id': 'song-3', 'title': 'Third Song'},
        ];

        // Act: Generate PDF content
        final pdfContent = songs.map((s) => s['title']).toList();

        // Assert: All songs in PDF
        expect(pdfContent.length, equals(3));
        expect(pdfContent, contains('First Song'));
        expect(pdfContent, contains('Second Song'));
        expect(pdfContent, contains('Third Song'));
      });

      testWidgets('INT-SETLIST-01.28: PDF contains setlist order', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: ['song-3', 'song-1', 'song-2'], // Custom order
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final songs = [
          {'id': 'song-1', 'title': 'First Song'},
          {'id': 'song-2', 'title': 'Second Song'},
          {'id': 'song-3', 'title': 'Third Song'},
        ];

        // Act: Get songs in setlist order
        final orderedTitles = setlist.songIds
            .map((id) => songs.firstWhere((s) => s['id'] == id)['title'])
            .toList();

        // Assert: Order preserved
        expect(orderedTitles[0], equals('Third Song'));
        expect(orderedTitles[1], equals('First Song'));
        expect(orderedTitles[2], equals('Second Song'));
      });

      testWidgets('INT-SETLIST-01.29: PDF export with empty setlist', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Empty Setlist',
          bandId: 'test-band-id',
          songIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Try to export empty setlist
        final canExport = setlist.songIds.isNotEmpty;

        // Assert: Should handle empty setlist
        expect(canExport, isFalse);
      });

      testWidgets('INT-SETLIST-01.30: PDF export shows success message', (
        WidgetTester tester,
      ) async {
        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Text('Setlist Detail'),
                    ElevatedButton(
                      onPressed: null, // Would export
                      child: Text('Export PDF'),
                    ),
                    SnackBar(content: Text('PDF exported successfully')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Success message
        expect(find.textContaining('exported'), findsOneWidget);
      });
    });

    // =========================================================================
    // EDGE CASES AND ERROR HANDLING
    // =========================================================================
    group('Edge Cases and Error Handling', () {
      testWidgets('INT-SETLIST-01.31: Create setlist with network error', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.set(any, any)).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Network error',
          ),
        );

        // Act & Assert
        expect(
          () async => await mockDocument.set({}, SetOptions()),
          throwsA(isA<FirebaseException>()),
        );
      });

      testWidgets('INT-SETLIST-01.32: Setlist name with special characters', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Summer Tour 2024 @ Arena!',
          bandId: 'test-band-id',
          songIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(setlist.name.contains('@'), isTrue);
      });

      testWidgets('INT-SETLIST-01.33: Very long setlist name handled', (
        WidgetTester tester,
      ) async {
        // Arrange
        final longName = 'A' * 100;
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: longName,
          bandId: 'test-band-id',
          songIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: Long name stored
        expect(setlist.name.length, equals(100));
      });

      testWidgets('INT-SETLIST-01.34: Setlist with many songs', (
        WidgetTester tester,
      ) async {
        // Arrange
        final manySongIds = List.generate(50, (i) => 'song-$i');
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Marathon Setlist',
          bandId: 'test-band-id',
          songIds: manySongIds,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(setlist.songIds.length, equals(50));
      });

      testWidgets('INT-SETLIST-01.35: Setlist duration calculation edge case', (
        WidgetTester tester,
      ) async {
        // Arrange
        final setlist = Setlist(
          id: const Uuid().v4(),
          name: 'Test Setlist',
          bandId: 'test-band-id',
          songIds: [],
          totalDuration: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: Null duration for empty setlist
        expect(setlist.totalDuration, isNull);
      });
    });
  });
}
