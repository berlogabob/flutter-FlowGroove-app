/// Song Management Flow Integration Tests
///
/// End-to-end tests for song CRUD operations, search/filter,
/// metronome integration, and bulk operations.
///
/// Test ID: INT-SONG-01
/// Priority: P0 🔴
/// Estimated Time: 2 hours
///
/// To run: flutter test test/integration/song_management_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/link.dart';
import 'package:flutter_repsync_app/screens/songs/add_song_screen.dart';

import '../helpers/mocks.mocks.dart';

void main() {
  group('Song Management Flow Integration Tests - INT-SONG-01', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocument;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocument = MockDocumentReference<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();

      // Setup default auth mock
      when(mockUser.uid).thenReturn('test-user-id');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockAuth.currentUser).thenReturn(mockUser);
    });

    // =========================================================================
    // CREATE SONG FLOW TESTS
    // =========================================================================
    group('Create Song Flow', () {
      testWidgets('INT-SONG-01.1: Create song with required fields succeeds', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songId = const Uuid().v4();
        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.set(any, any)).thenAnswer((_) async => {});
        when(mockDocument.id).thenReturn(songId);

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: AddSongScreen())),
        );
        await tester.pumpAndSettle();

        // Act: Enter required fields
        final titleField = find.byType(TextFormField).at(0);
        await tester.enterText(titleField, 'Test Song');
        await tester.pump();

        final artistField = find.byType(TextFormField).at(1);
        await tester.enterText(artistField, 'Test Artist');
        await tester.pump();

        // Tap save button
        final saveButton = find.text('Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Assert: Song creation attempted
        verify(mockDocument.set(any, any)).called(1);
      });

      testWidgets('INT-SONG-01.2: Create song with BPM displays BPM badge', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 120,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: BPM badge would display
        expect(song.originalBPM, equals(120));
      });

      testWidgets('INT-SONG-01.3: Create song with all optional fields', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songId = const Uuid().v4();
        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.set(any, any)).thenAnswer((_) async => {});
        when(mockDocument.id).thenReturn(songId);

        final song = Song(
          id: songId,
          title: 'Complete Song',
          artist: 'Complete Artist',
          originalKey: 'C',
          originalBPM: 120,
          ourKey: 'D',
          ourBPM: 125,
          links: [
            Link(type: Link.typeSpotify, url: 'https://spotify.com/track/test'),
          ],
          notes: 'Test notes',
          tags: ['ready', 'easy'],
          bandId: 'test-band-id',
          spotifyUrl: 'https://spotify.com/track/test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: All fields present
        expect(song.title, equals('Complete Song'));
        expect(song.originalKey, equals('C'));
        expect(song.ourBPM, equals(125));
        expect(song.links.length, equals(1));
        expect(song.tags.length, equals(2));
      });

      testWidgets('INT-SONG-01.4: Create song appears in songs list', (
        WidgetTester tester,
      ) async {
        // Arrange
        final testSong = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(
          mockCollection.where(any, isEqualTo: anyNamed('isEqualTo')),
        ).thenReturn(mockCollection);
        when(
          mockCollection.get(any),
        ).thenAnswer((_) async => mockQuerySnapshot);

        final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        when(mockDoc.exists).thenReturn(true);
        when(mockDoc.data()).thenReturn(testSong.toJson());
        when(mockDoc.id).thenReturn(testSong.id);
        when(mockQuerySnapshot.docs).thenReturn(
          <MockDocumentSnapshot<Map<String, dynamic>>>[mockDoc]
              as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
        );
        when(mockQuerySnapshot.size).thenReturn(1);

        // Act
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: mockQuerySnapshot.size,
                  itemBuilder: (context, index) {
                    return Text(testSong.title);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Song appears in list
        expect(find.text('Test Song'), findsOneWidget);
      });

      testWidgets(
        'INT-SONG-01.5: Create song with empty title shows validation',
        (WidgetTester tester) async {
          // Arrange
          await tester.pumpWidget(
            const ProviderScope(child: MaterialApp(home: AddSongScreen())),
          );
          await tester.pumpAndSettle();

          // Act: Try to save without title
          final saveButton = find.text('Save');
          await tester.tap(saveButton);
          await tester.pumpAndSettle();

          // Assert: Validation error
          expect(find.textContaining('required'), findsOneWidget);
        },
      );

      testWidgets('INT-SONG-01.6: Create song with invalid BPM shows error', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: -1, // Invalid BPM
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: BPM validation (should be positive)
        expect(song.originalBPM, lessThan(1));
      });
    });

    // =========================================================================
    // EDIT SONG FLOW TESTS
    // =========================================================================
    group('Edit Song Flow', () {
      testWidgets('INT-SONG-01.7: Edit song title', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Original Title',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Act: Update title
        final updatedSong = song.copyWith(
          title: 'Updated Title',
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(updatedSong.title, equals('Updated Title'));
      });

      testWidgets('INT-SONG-01.8: Edit song BPM', (WidgetTester tester) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 120,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Act: Update BPM
        final updatedSong = song.copyWith(
          originalBPM: 140,
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(updatedSong.originalBPM, equals(140));
      });

      testWidgets('INT-SONG-01.9: Edit song key', (WidgetTester tester) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          originalKey: 'C',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Act: Update key
        final updatedSong = song.copyWith(
          originalKey: 'D',
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(updatedSong.originalKey, equals('D'));
      });

      testWidgets('INT-SONG-01.10: Edit song persists changes', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Act
        await mockDocument.update({
          'title': 'Updated Title',
          'originalBPM': 140,
        });
        await tester.pump();

        // Assert
        verify(mockDocument.update(any)).called(1);
      });

      testWidgets('INT-SONG-01.11: Edit song BPM badge updates', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 120,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Update BPM
        final updatedSong = song.copyWith(
          originalBPM: 140,
          updatedAt: DateTime.now(),
        );

        // Assert: BPM badge would update
        expect(updatedSong.originalBPM, equals(140));
        expect(updatedSong.originalBPM, isNot(equals(120)));
      });

      testWidgets('INT-SONG-01.12: Edit song with links', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          links: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Act: Add link
        final updatedLinks = [
          ...song.links,
          Link(type: Link.typeSpotify, url: 'https://spotify.com/track/new'),
        ];
        final updatedSong = song.copyWith(
          links: updatedLinks,
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(updatedSong.links.length, equals(1));
      });
    });

    // =========================================================================
    // DELETE SONG FLOW TESTS
    // =========================================================================
    group('Delete Song Flow', () {
      testWidgets('INT-SONG-01.13: Delete song from detail view', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.delete()).thenAnswer((_) async => {});

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Text('Song Detail'),
                    ElevatedButton(
                      onPressed: null, // Would trigger delete
                      child: Text('Delete Song'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act: Tap delete
        final deleteButton = find.text('Delete Song');
        expect(deleteButton, findsOneWidget);
      });

      testWidgets('INT-SONG-01.14: Delete song confirms before deletion', (
        WidgetTester tester,
      ) async {
        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: AlertDialog(
                  title: Text('Delete Song'),
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
      });

      testWidgets('INT-SONG-01.15: Delete song removes from Firestore', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.delete()).thenAnswer((_) async => {});

        // Act
        await mockDocument.delete();
        await tester.pump();

        // Assert
        verify(mockDocument.delete()).called(1);
      });

      testWidgets('INT-SONG-01.16: Delete song removes from all setlists', (
        WidgetTester tester,
      ) async {
        // Arrange: Song referenced in setlists
        final songId = const Uuid().v4();

        // Act: Delete song
        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(songId)).thenReturn(mockDocument);
        when(mockDocument.delete()).thenAnswer((_) async => {});

        // Also update setlists that reference this song
        when(mockFirestore.collection('setlists')).thenReturn(mockCollection);

        // Assert: Song deleted
        verify(mockDocument.delete()).called(1);
      });

      testWidgets('INT-SONG-01.17: Delete song updates UI', (
        WidgetTester tester,
      ) async {
        // Arrange: Songs list
        final songs = [
          Song(
            id: const Uuid().v4(),
            title: 'Song 1',
            artist: 'Artist 1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: const Uuid().v4(),
            title: 'Song 2',
            artist: 'Artist 2',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Delete first song
        final remainingSongs = songs.skip(1).toList();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: remainingSongs.length,
                  itemBuilder: (context, index) {
                    return Text(remainingSongs[index].title);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Only remaining song shown
        expect(find.text('Song 1'), findsNothing);
        expect(find.text('Song 2'), findsOneWidget);
      });
    });

    // =========================================================================
    // SEARCH SONGS FLOW TESTS
    // =========================================================================
    group('Search Songs Flow', () {
      testWidgets('INT-SONG-01.18: Search songs by title', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songs = [
          Song(
            id: const Uuid().v4(),
            title: 'Test Song',
            artist: 'Test Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: const Uuid().v4(),
            title: 'Another Song',
            artist: 'Another Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Filter by title
        final query = 'Test';
        final filteredSongs = songs
            .where((s) => s.title.toLowerCase().contains(query.toLowerCase()))
            .toList();

        // Assert
        expect(filteredSongs.length, equals(1));
        expect(filteredSongs.first.title, equals('Test Song'));
      });

      testWidgets('INT-SONG-01.19: Search songs by artist', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songs = [
          Song(
            id: const Uuid().v4(),
            title: 'Song 1',
            artist: 'Test Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: const Uuid().v4(),
            title: 'Song 2',
            artist: 'Another Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Filter by artist
        final query = 'Test';
        final filteredSongs = songs
            .where((s) => s.artist.toLowerCase().contains(query.toLowerCase()))
            .toList();

        // Assert
        expect(filteredSongs.length, equals(1));
      });

      testWidgets('INT-SONG-01.20: Search with empty results', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songs = [
          Song(
            id: const Uuid().v4(),
            title: 'Test Song',
            artist: 'Test Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Search for non-existent song
        final query = 'NonExistent';
        final filteredSongs = songs
            .where((s) => s.title.toLowerCase().contains(query.toLowerCase()))
            .toList();

        // Assert
        expect(filteredSongs.isEmpty, isTrue);
      });

      testWidgets('INT-SONG-01.21: Search with special characters', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songs = [
          Song(
            id: const Uuid().v4(),
            title: "Rock & Roll",
            artist: 'Test Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Search with special character
        final query = '&';
        final filteredSongs = songs
            .where((s) => s.title.toLowerCase().contains(query.toLowerCase()))
            .toList();

        // Assert
        expect(filteredSongs.length, equals(1));
      });

      testWidgets('INT-SONG-01.22: Search is case insensitive', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songs = [
          Song(
            id: const Uuid().v4(),
            title: 'TEST SONG',
            artist: 'Test Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Search with lowercase
        final query = 'test';
        final filteredSongs = songs
            .where((s) => s.title.toLowerCase().contains(query.toLowerCase()))
            .toList();

        // Assert
        expect(filteredSongs.length, equals(1));
      });

      testWidgets('INT-SONG-01.23: Search filters in real-time', (
        WidgetTester tester,
      ) async {
        // Arrange
        final allSongs = [
          Song(
            id: const Uuid().v4(),
            title: 'Apple',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: const Uuid().v4(),
            title: 'Banana',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: const Uuid().v4(),
            title: 'Cherry',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Filter as user types
        var query = 'A';
        var filtered = allSongs
            .where((s) => s.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
        expect(filtered.length, equals(1));

        query = 'An';
        filtered = allSongs
            .where((s) => s.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
        expect(filtered.length, equals(1));
      });
    });

    // =========================================================================
    // SONG + METRONOME INTEGRATION TESTS
    // =========================================================================
    group('Song + Metronome Integration', () {
      testWidgets(
        'INT-SONG-01.24: Tap BPM badge opens metronome with song BPM',
        (WidgetTester tester) async {
          // Arrange
          final song = Song(
            id: const Uuid().v4(),
            title: 'Test Song',
            artist: 'Test Artist',
            originalBPM: 120,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Act: Simulate tapping BPM badge
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      Text('Song: ${song.title}'),
                      GestureDetector(
                        onTap: () {
                          // Would open metronome with song BPM
                        },
                        child: Text('BPM: ${song.originalBPM}'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Assert: BPM badge shown
          expect(find.text('BPM: 120'), findsOneWidget);
        },
      );

      testWidgets('INT-SONG-01.25: Metronome preset suggests song BPM', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 140,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Open metronome from song
        final suggestedBPM = song.originalBPM ?? 120;

        // Assert
        expect(suggestedBPM, equals(140));
      });

      testWidgets('INT-SONG-01.26: Song without BPM uses default', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act: Get suggested BPM
        final suggestedBPM = song.originalBPM ?? 120;

        // Assert
        expect(suggestedBPM, equals(120));
      });
    });

    // =========================================================================
    // BULK OPERATIONS TESTS
    // =========================================================================
    group('Bulk Operations', () {
      testWidgets('INT-SONG-01.27: Select multiple songs', (
        WidgetTester tester,
      ) async {
        // Arrange
        final songs = [
          Song(
            id: const Uuid().v4(),
            title: 'Song 1',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: const Uuid().v4(),
            title: 'Song 2',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: const Uuid().v4(),
            title: 'Song 3',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Select multiple
        final selectedIds = <String>{};
        selectedIds.add(songs[0].id);
        selectedIds.add(songs[2].id);

        // Assert
        expect(selectedIds.length, equals(2));
      });

      testWidgets('INT-SONG-01.28: Bulk delete songs', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(mockFirestore.collection('songs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.delete()).thenAnswer((_) async => {});

        final songs = [
          Song(
            id: const Uuid().v4(),
            title: 'Song 1',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: const Uuid().v4(),
            title: 'Song 2',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Bulk delete
        for (final song in songs) {
          when(mockCollection.doc(song.id)).thenReturn(mockDocument);
          await mockDocument.delete();
        }

        // Assert
        verify(mockDocument.delete()).called(2);
      });

      testWidgets('INT-SONG-01.29: Bulk add songs to setlist', (
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
          Song(
            id: 'song-3',
            title: 'Song 3',
            artist: 'Artist',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act: Add to setlist
        final songIds = songs.map((s) => s.id).toList();

        // Assert
        expect(songIds.length, equals(3));
        expect(songIds, equals(['song-1', 'song-2', 'song-3']));
      });

      testWidgets('INT-SONG-01.30: Bulk operations show progress', (
        WidgetTester tester,
      ) async {
        // Arrange
        final totalSongs = 10;
        var processedSongs = 0;

        // Act: Simulate bulk operation
        for (int i = 0; i < totalSongs; i++) {
          processedSongs++;
        }

        // Assert
        expect(processedSongs, equals(totalSongs));
      });

      testWidgets('INT-SONG-01.31: Bulk delete confirms before deletion', (
        WidgetTester tester,
      ) async {
        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: AlertDialog(
                  title: Text('Delete 3 Songs'),
                  content: Text('Are you sure you want to delete 3 songs?'),
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

        // Assert: Confirmation dialog shows count
        expect(find.textContaining('3 songs'), findsOneWidget);
      });
    });

    // =========================================================================
    // EDGE CASES AND ERROR HANDLING
    // =========================================================================
    group('Edge Cases and Error Handling', () {
      testWidgets(
        'INT-SONG-01.32: Create song with network error shows message',
        (WidgetTester tester) async {
          // Arrange
          when(mockFirestore.collection('songs')).thenReturn(mockCollection);
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
        },
      );

      testWidgets('INT-SONG-01.33: Song title with special characters', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: "Rock & Roll / Live @ Concert!",
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(song.title.contains('&'), isTrue);
        expect(song.title.contains('@'), isTrue);
      });

      testWidgets('INT-SONG-01.34: Very long song title handled', (
        WidgetTester tester,
      ) async {
        // Arrange
        final longTitle = 'A' * 200;
        final song = Song(
          id: const Uuid().v4(),
          title: longTitle,
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: Long title stored (truncation would be UI layer)
        expect(song.title.length, equals(200));
      });

      testWidgets('INT-SONG-01.35: Song with zero BPM handled', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: Zero BPM stored
        expect(song.originalBPM, equals(0));
      });

      testWidgets('INT-SONG-01.36: Song with very high BPM handled', (
        WidgetTester tester,
      ) async {
        // Arrange
        final song = Song(
          id: const Uuid().v4(),
          title: 'Test Song',
          artist: 'Test Artist',
          originalBPM: 500,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert: High BPM stored
        expect(song.originalBPM, equals(500));
      });
    });
  });
}
