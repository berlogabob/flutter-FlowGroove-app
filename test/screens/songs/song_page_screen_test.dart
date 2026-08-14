import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/providers/song_autocomplete_provider.dart';
import 'package:flowgroove/screens/songs/add_song_screen.dart';
import 'package:flowgroove/screens/songs/song_page_screen.dart';
import 'package:flowgroove/widgets/menu_items_scope.dart';
import 'package:flowgroove/widgets/performance_sheet_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.dart';
import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_helpers.dart';

class _TestAutocompleteNotifier extends AutocompleteSearchNotifier {
  @override
  AutocompleteSearchState build() => const AutocompleteSearchState.initial();

  @override
  void init({String? userId, String? bandId}) {
    // No-op: don't access FirebaseAuth in tests.
  }
}

class _TestAppUserNotifier extends AppUserNotifier {
  _TestAppUserNotifier(this.mockUser);
  final AppUser? mockUser;

  @override
  AsyncValue<AppUser?> build() => AsyncValue.data(mockUser);
}

class _SignedInUserNotifier extends AppUserNotifier {
  @override
  AsyncValue<AppUser?> build() =>
      AsyncValue.data(MockDataHelper.createMockAppUser());
}

class _DemoUserNotifier extends AppUserNotifier {
  @override
  AsyncValue<AppUser?> build() => AsyncValue.data(
    MockDataHelper.createMockAppUser().copyWith(accessRole: 'demo'),
  );
}

void main() {
  group('SongPageScreen', () {
    late MockFirebaseAuth mockAuth;

    setUp(() async {
      mockAuth = MockFirebaseAuth();
      await initializeFirebaseForTests();
    });

    List<Override> overrides({
      List<Section> sections = const [],
      AppUserNotifier? appUserNotifier,
    }) {
      final song = MockDataHelper.createMockSong(
        id: 's1',
      ).copyWith(sections: sections);
      return [
        firebaseAuthProvider.overrideWith((ref) => mockAuth),
        appUserProvider.overrideWith(
          () => appUserNotifier ??
              _TestAppUserNotifier(MockDataHelper.createMockAppUser()),
        ),
        autocompleteSearchProvider.overrideWith(_TestAutocompleteNotifier.new),
        songsProvider.overrideWith((ref) => Stream.value([song])),
        // Without this, a signed-in uid makes bandsProvider hit the real
        // repository, error, and arm Riverpod retry timers that trip the
        // pending-timer invariant at test end.
        bandsProvider.overrideWith((ref) => Stream.value(const <Band>[])),
      ];
    }

    Widget page({String? initialTab}) => SongPageScreen(
      songId: 's1',
      initialSong: MockDataHelper.createMockSong(id: 's1'),
      initialTab: initialTab,
    );

    testWidgets('defaults to the Edit tab', (tester) async {
      await pumpAppWidget(tester, page(), overrides: overrides());
      await tester.pumpAndSettle();

      expect(find.byType(AddSongScreen), findsOneWidget);
      // Sheet tab is lazy — never visited, so its view is not built.
      expect(find.byType(PerformanceSheetView), findsNothing);
    });

    testWidgets('segments render in Edit · Sheet · Lab order', (tester) async {
      await pumpAppWidget(tester, page(), overrides: overrides());
      await tester.pumpAndSettle();

      final editX = tester.getCenter(find.text('Edit')).dx;
      final sheetX = tester.getCenter(find.text('Sheet')).dx;
      final labX = tester.getCenter(find.text('Lab')).dx;
      expect(editX, lessThan(sheetX));
      expect(sheetX, lessThan(labX));
    });

    testWidgets('initialTab sheet lands on the Sheet tab', (tester) async {
      await pumpAppWidget(
        tester,
        page(initialTab: 'sheet'),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PerformanceSheetView), findsOneWidget);
      // Edit tab is lazy — not visited, so the form is not built.
      expect(find.byType(AddSongScreen), findsNothing);
    });

    testWidgets('Stage button shows only on the Sheet tab with content', (
      tester,
    ) async {
      final sections = [
        Section(
          id: 'sec1',
          name: 'Verse',
          duration: 30,
          chordChart: '[C]Hello [G]world',
        ),
      ];
      await pumpAppWidget(
        tester,
        page(initialTab: 'sheet'),
        overrides: overrides(sections: sections),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Stage mode'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Stage mode'), findsNothing);
    });

    testWidgets('page menu carries the Song editor entry', (tester) async {
      final user = MockUser();
      when(user.uid).thenReturn('test-user-id');

      final overridesList = [
        ...overrides(appUserNotifier: _SignedInUserNotifier()),
        currentUserProvider.overrideWithValue(AsyncValue<User?>.data(user)),
      ];
      await pumpAppWidget(tester, page(), overrides: overridesList);
      await tester.pumpAndSettle();

      final scope = tester.widget<MenuItemsScope>(
        find.byType(MenuItemsScope).first,
      );
      final labels = scope.items.map((i) => i.label).toList();
      expect(labels, contains('Song editor'));
      expect(labels, contains('Export PDF'));
      expect(labels, contains('Export ChordPro'));
    });

    testWidgets('menu hides Song editor for demo users', (tester) async {
      final user = MockUser();
      when(user.uid).thenReturn('test-user-id');

      final overridesList = [
        ...overrides(appUserNotifier: _DemoUserNotifier()),
        currentUserProvider.overrideWithValue(AsyncValue<User?>.data(user)),
      ];
      await pumpAppWidget(tester, page(), overrides: overridesList);
      await tester.pumpAndSettle();

      final scope = tester.widget<MenuItemsScope>(
        find.byType(MenuItemsScope).first,
      );
      final labels = scope.items.map((i) => i.label).toList();
      expect(labels, isNot(contains('Song editor')));
      expect(labels, contains('Export PDF'));
      expect(labels, contains('Export ChordPro'));
    });

    testWidgets('menu shows Song editor for signed-in non-demo user',
        (tester) async {
      final user = MockUser();
      when(user.uid).thenReturn('test-user-id');

      final overridesList = [
        ...overrides(appUserNotifier: _SignedInUserNotifier()),
        currentUserProvider.overrideWithValue(AsyncValue<User?>.data(user)),
      ];
      await pumpAppWidget(tester, page(), overrides: overridesList);
      await tester.pumpAndSettle();

      final scope = tester.widget<MenuItemsScope>(
        find.byType(MenuItemsScope).first,
      );
      final labels = scope.items.map((i) => i.label).toList();
      expect(labels, contains('Song editor'));
      expect(labels, contains('Export PDF'));
      expect(labels, contains('Export ChordPro'));
    });

    // Band copies hide the Edit tab from non-editors: the save could only be
    // rules-denied, and the old always-visible editor let viewers type a
    // whole song and lose it.
    Widget bandPage({String? initialTab}) => SongPageScreen(
      songId: 's1',
      initialSong: MockDataHelper.createMockSong(id: 's1', bandId: 'b1'),
      bandId: 'b1',
      initialTab: initialTab,
    );

    List<Override> bandOverrides({required bool canEdit}) => [
      ...overrides(appUserNotifier: _SignedInUserNotifier()),
      canEditBandProvider('b1').overrideWithValue(canEdit),
      bandSongsProvider.overrideWith(
        (ref, id) =>
            Stream.value([MockDataHelper.createMockSong(id: 's1', bandId: 'b1')]),
      ),
    ];

    testWidgets(
      'band non-editor: Edit segment hidden and tab=edit lands on Sheet',
      (tester) async {
        await pumpAppWidget(
          tester,
          bandPage(initialTab: 'edit'),
          overrides: bandOverrides(canEdit: false),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsNothing);
        expect(find.byType(AddSongScreen), findsNothing);
        // Coerced onto the Sheet tab (empty song → its empty state), with the
        // "Add lyrics & chords" door into Edit hidden too.
        expect(find.byType(PerformanceSheetView), findsOneWidget);
        expect(find.text('Add lyrics & chords'), findsNothing);
      },
    );

    testWidgets('band editor keeps the Edit tab', (tester) async {
      await pumpAppWidget(
        tester,
        bandPage(),
        overrides: bandOverrides(canEdit: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.byType(AddSongScreen), findsOneWidget);
    });
  });
}
