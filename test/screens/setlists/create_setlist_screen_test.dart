import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/setlists/create_setlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  group('CreateSetlistScreen', () {
    testWidgets('saves a new setlist with the provided bandId', (tester) async {
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      final firestore = MockFirestoreService();
      when(
        firestore.saveSetlist(any, uid: anyNamed('uid')),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              AsyncValue<User?>.data(firebaseUser),
            ),
            firestoreProvider.overrideWithValue(firestore),
            bandSongsProvider.overrideWith(
              (ref, bandId) => Stream<List<Song>>.value([]),
            ),
            setlistsProvider.overrideWith(
              (ref) => Stream<List<Setlist>>.value([]),
            ),
          ],
          child: const MaterialApp(
            home: CreateSetlistScreen(bandId: 'band-123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Gig Night');
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final verification = verify(
        firestore.saveSetlist(captureAny, uid: 'test-user-id'),
      )..called(1);
      final savedSetlist = verification.captured.single as Setlist;
      expect(savedSetlist.name, 'Gig Night');
      expect(savedSetlist.bandId, 'band-123');
    });

    testWidgets('saves a band-scoped setlist to the shared band collection', (
      tester,
    ) async {
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      final firestore = MockFirestoreService();
      when(firestore.saveBandSetlist(any, any)).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              AsyncValue<User?>.data(firebaseUser),
            ),
            firestoreProvider.overrideWithValue(firestore),
            bandSongsProvider.overrideWith(
              (ref, bandId) => Stream<List<Song>>.value([]),
            ),
            setlistsProvider.overrideWith(
              (ref) => Stream<List<Setlist>>.value([]),
            ),
            bandSetlistsProvider.overrideWith(
              (ref, bandId) => Stream<List<Setlist>>.value([]),
            ),
          ],
          child: const MaterialApp(
            home: CreateSetlistScreen(
              bandId: 'band-123',
              storageScope: SetlistStorageScope.band,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Shared Gig');
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final verification = verify(
        firestore.saveBandSetlist(captureAny, 'band-123'),
      )..called(1);
      final savedSetlist = verification.captured.single as Setlist;
      expect(savedSetlist.name, 'Shared Gig');
      expect(savedSetlist.bandId, 'band-123');
      verifyNever(firestore.saveSetlist(any, uid: anyNamed('uid')));
    });
  });
}
