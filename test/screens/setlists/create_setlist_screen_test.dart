import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/setlists/create_setlist_screen.dart';
import 'package:flowgroove/widgets/menu_items_scope.dart';
import 'package:flowgroove/widgets/primary_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.dart' show MockDataHelper;
import '../../helpers/mocks.mocks.dart';

void main() {
  group('CreateSetlistScreen', () {
    // Was 'saves a new setlist with the provided bandId', which asserted that
    // `CreateSetlistScreen(bandId: 'band-123')` saved to the PERSONAL
    // collection. That combination is never produced by the app — every caller
    // passing a bandId also passes scope: band — and the result was invisible,
    // because the personal list filters out entries with a bandId. Band scope
    // is now derived from the setlist, so the case this covers is a genuinely
    // personal setlist: no band, saved personally.
    testWidgets('saves a new personal setlist to the personal collection', (
      tester,
    ) async {
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
          child: const MaterialApp(home: CreateSetlistScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Gig Night');
      // Save lives in the bottom PrimaryActionBar.
      await tester.tap(find.widgetWithText(PrimaryActionBar, 'Create Setlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final verification = verify(
        firestore.saveSetlist(captureAny, uid: 'test-user-id'),
      )..called(1);
      final savedSetlist = verification.captured.single as Setlist;
      expect(savedSetlist.name, 'Gig Night');
      expect(savedSetlist.bandId, isEmpty);
      verifyNever(firestore.saveBandSetlist(any, any));
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
      // Save lives in the bottom PrimaryActionBar.
      await tester.tap(find.widgetWithText(PrimaryActionBar, 'Create Setlist'));
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

    testWidgets(
      'a setlist carrying a bandId saves to the band even if scope says personal',
      (tester) async {
        // Regression: a caller that forgets `scope` used to send the edit into
        // users/{uid}/setlists, where the personal list then hid it (it filters
        // out a non-empty bandId). The save looked fine and the edit was gone.
        // Scope is derived from the setlist itself so that can't happen.
        final firebaseUser = MockUser();
        when(firebaseUser.uid).thenReturn('test-user-id');

        final firestore = MockFirestoreService();
        when(firestore.saveBandSetlist(any, any)).thenAnswer((_) async {});

        final existing = MockDataHelper.createMockSetlist(
          id: 'setlist-9',
          bandId: 'band-123',
          name: 'Band Gig',
        );

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
            child: MaterialApp(
              home: CreateSetlistScreen(
                setlist: existing,
                // Deliberately wrong — this is what the buggy caller passed.
                storageScope: SetlistStorageScope.personal,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(PrimaryActionBar, 'Save Changes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        verify(firestore.saveBandSetlist(any, 'band-123')).called(1);
        verifyNever(firestore.saveSetlist(any, uid: anyNamed('uid')));
      },
    );

    testWidgets('shows an error instead of throwing when shared save fails', (
      tester,
    ) async {
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      final firestore = MockFirestoreService();
      when(
        firestore.saveBandSetlist(any, any),
      ).thenThrow(Exception('permission-denied'));

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
      // Save lives in the bottom PrimaryActionBar.
      await tester.tap(find.widgetWithText(PrimaryActionBar, 'Create Setlist'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not save the shared setlist. Check your band permissions and try again.',
        ),
        findsOneWidget,
      );
      // No top app bar in this standalone pump (no shell to show it in the
      // bottom bar); the screen still publishes the title locally.
      final scope = tester.widget<MenuItemsScope>(find.byType(MenuItemsScope));
      expect(scope.title, 'Create Band Setlist');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'edit mode renders an unresolvable entry as a placeholder row and '
      'round-trips it unchanged on save',
      (tester) async {
        final firebaseUser = MockUser();
        when(firebaseUser.uid).thenReturn('test-user-id');

        final firestore = MockFirestoreService();
        when(
          firestore.saveSetlist(any, uid: anyNamed('uid')),
        ).thenAnswer((_) async {});

        // One entry resolves (song-1), one doesn't (orphan-song) — e.g. the
        // song behind it was deleted. Both must survive editing and saving.
        final existingSetlist = Setlist(
          id: 'setlist-1',
          bandId: '',
          name: 'Gig Night',
          items: const [
            SetlistItem(id: 'item-1', songId: 'song-1'),
            SetlistItem(id: 'item-2', songId: 'orphan-song'),
          ],
          songIds: const ['song-1', 'orphan-song'],
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );
        final song = Song(
          id: 'song-1',
          title: 'Known Song',
          artist: 'Known Artist',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWithValue(
                AsyncValue<User?>.data(firebaseUser),
              ),
              firestoreProvider.overrideWithValue(firestore),
              songsProvider.overrideWith(
                (ref) => Stream<List<Song>>.value([song]),
              ),
              setlistsProvider.overrideWith(
                (ref) => Stream<List<Setlist>>.value([existingSetlist]),
              ),
            ],
            child: MaterialApp(
              home: CreateSetlistScreen(setlist: existingSetlist),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both entries are rendered — the raw count, not just the resolvable
        // one — and the orphan shows as an "Unavailable song" placeholder
        // instead of being dropped.
        expect(find.text('Songs (2)'), findsOneWidget);
        expect(find.text('Known Song'), findsOneWidget);
        expect(find.text('Unavailable song'), findsOneWidget);

        await tester.tap(find.widgetWithText(PrimaryActionBar, 'Save Changes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final verification = verify(
          firestore.saveSetlist(captureAny, uid: 'test-user-id'),
        )..called(1);
        final savedSetlist = verification.captured.single as Setlist;

        // No silent deletion: both entries, including the orphan, round-trip
        // unchanged.
        expect(savedSetlist.items.map((item) => item.songId).toList(), [
          'song-1',
          'orphan-song',
        ]);
        expect(savedSetlist.songIds, ['song-1', 'orphan-song']);
      },
    );
  });
}
