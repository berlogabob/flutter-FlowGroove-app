import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/song_autocomplete_provider.dart';
import 'package:flowgroove/screens/songs/add_song_screen.dart';
import 'package:flowgroove/screens/songs/song_page_screen.dart';
import 'package:flowgroove/widgets/menu_items_scope.dart';
import 'package:flowgroove/widgets/performance_sheet_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('SongPageScreen', () {
    late MockFirebaseAuth mockAuth;

    setUp(() async {
      mockAuth = MockFirebaseAuth();
      await initializeFirebaseForTests();
    });

    List<Override> overrides({List<Section> sections = const []}) {
      final song = MockDataHelper.createMockSong(
        id: 's1',
      ).copyWith(sections: sections);
      return [
        firebaseAuthProvider.overrideWith((ref) => mockAuth),
        appUserProvider.overrideWith(
          () => _TestAppUserNotifier(MockDataHelper.createMockAppUser()),
        ),
        autocompleteSearchProvider.overrideWith(_TestAutocompleteNotifier.new),
        songsProvider.overrideWith((ref) => Stream.value([song])),
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
      await pumpAppWidget(tester, page(), overrides: overrides());
      await tester.pumpAndSettle();

      final scope = tester.widget<MenuItemsScope>(
        find.byType(MenuItemsScope).first,
      );
      final labels = scope.items.map((i) => i.label).toList();
      expect(labels, contains('Song editor'));
      expect(labels, contains('Export PDF'));
      expect(labels, contains('Export ChordPro'));
    });
  });
}
