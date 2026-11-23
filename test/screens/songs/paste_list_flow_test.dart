import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/screens/bands/band_songs_screen.dart';
import 'package:flowgroove/screens/setlists/create_setlist_screen.dart';
import 'package:flowgroove/screens/songs/components/paste_list/paste_list_flow.dart';
import 'package:flowgroove/services/paste/pasted_song_parser.dart';
import 'package:flowgroove/widgets/menu_items_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.dart' show MockDataHelper;
import '../../helpers/mocks.mocks.dart' show MockUser;
import '../../helpers/routed_test_harness.dart';
import '../../providers/data_providers_test.mocks.dart' as repositories;

Song _song(String id, String title, [String artist = '']) => Song(
  id: id,
  title: title,
  artist: artist,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

Future<void> _pumpSheet(
  WidgetTester tester,
  String text,
  List<Song> library, {
  void Function(List<ReviewedSong>?)? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => (onResult ?? (_) {})(
              await showModalBottomSheet<List<ReviewedSong>>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ReviewPastedSongsSheet(
                  pasted: parsePastedSongs(text),
                  library: library,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Types [text] in the paste sheet, reviews, and confirms.
Future<void> _pasteAndConfirm(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(PasteListInputSheet),
      matching: find.byType(TextFormField),
    ),
    text,
  );
  await tester.pump();
  await tester.tap(find.text('Review'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Review '), findsOneWidget);
  await tester.tap(
    find.descendant(
      of: find.byType(ReviewPastedSongsSheet),
      matching: find.byType(ElevatedButton),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ReviewPastedSongsSheet', () {
    testWidgets('count, NEW tag vs library match, edit, remove, add row', (
      tester,
    ) async {
      List<ReviewedSong>? result;
      await _pumpSheet(tester, '1. Snowman - Sia\n2. Imagine - John Lennon', [
        _song('lib-1', 'imagine', 'john lennon'),
      ], onResult: (r) => result = r);
      expect(find.text('Review 2 songs'), findsOneWidget);
      expect(find.text('Add 2 songs'), findsOneWidget);
      // Only the unmatched row is NEW.
      expect(
        find.byWidgetPredicate((w) => w is Visibility && w.visible),
        findsOneWidget,
      );
      expect(find.text('Snowman'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Snowman'),
        'Snowman 2',
      );
      await tester.pump();
      expect(find.text('Snowman 2'), findsOneWidget);

      await tester.tap(find.text('Add another song'));
      await tester.pump();
      // Empty-title row is not counted.
      expect(find.text('Add 2 songs'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove').first);
      await tester.pump();
      expect(find.text('Review 1 song'), findsOneWidget);
      expect(find.text('Add 1 song'), findsOneWidget);

      await tester.tap(find.text('Add 1 song'));
      await tester.pumpAndSettle();
      expect(result!.single.existing?.id, 'lib-1');
    });

    testWidgets('button disabled at 0 songs', (tester) async {
      await _pumpSheet(tester, 'Only One', const []);
      await tester.tap(find.byTooltip('Remove'));
      await tester.pump();
      expect(find.text('Add 0 songs'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Add 0 songs'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('entry points', () {
    late repositories.MockSongRepository repo;
    late MockUser firebaseUser;
    late AppUser appUser;

    setUp(() {
      repo = repositories.MockSongRepository();
      when(repo.saveSong(any, uid: anyNamed('uid'))).thenAnswer((_) async {});
      when(repo.saveBandSong(any, any)).thenAnswer((_) async {});
      firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');
      appUser = MockDataHelper.createMockAppUser();
    });

    List<dynamic> overrides(List<Song> songs) => [
      appUserProvider.overrideWith(() => TestAppUserNotifier(appUser)),
      currentUserProvider.overrideWithValue(
        AsyncValue<User?>.data(firebaseUser),
      ),
      songRepositoryProvider.overrideWithValue(repo),
      songsProvider.overrideWith((ref) => Stream.value(songs)),
      bandSongsProvider.overrideWith((ref, id) => Stream.value(songs)),
      bandsProvider.overrideWith((ref) => Stream<List<Band>>.value([])),
      setlistsProvider.overrideWith((ref) => Stream<List<Setlist>>.value([])),
    ];

    testWidgets('Songs tab menu: paste, review, songs saved to library', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overrides([_song('a', 'Existing')]),
      );
      await tester.tap(find.byTooltip('Library actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste a list'));
      await tester.pumpAndSettle();
      await _pasteAndConfirm(tester, '1. Snowman - Sia\n2. Santa Baby');

      verify(repo.saveSong(any, uid: 'test-user-id')).called(2);
      verifyNever(repo.saveBandSong(any, any));
      expect(find.text('2 songs added'), findsOneWidget);
    });

    testWidgets('Band songs menu: paste, review, songs saved to the band', (
      tester,
    ) async {
      final band = MockDataHelper.createMockBand(id: 'band-123');
      final router = createRoutedTestRouter(
        initialLocation: '/library',
        routes: [
          GoRoute(
            path: '/library',
            builder: (_, _) => BandSongsScreen(band: band),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides(const []).cast(),
            canEditBandProvider.overrideWith((ref, id) => true),
            isBandAdminProvider.overrideWith((ref, id) => true),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final items = tester
          .widget<MenuItemsScope>(find.byType(MenuItemsScope).first)
          .items;
      expect(items.map((i) => i.label), ['Paste a list', 'Export to CSV']);
      items.first.onTap!();
      await tester.pumpAndSettle();
      await _pasteAndConfirm(tester, 'Snowman - Sia');

      final saved =
          verify(repo.saveBandSong(captureAny, 'band-123')).captured.single
              as Song;
      expect(saved.title, 'Snowman');
      expect(saved.bandId, 'band-123');
      verifyNever(repo.saveSong(any, uid: anyNamed('uid')));
    });

    testWidgets('Setlist: paste adds songs in order, Undo removes them', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides([_song('lib-1', 'Imagine', 'Lennon')]).cast(),
          ],
          child: const MaterialApp(home: CreateSetlistScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Songs (0)'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste a list'));
      await tester.pumpAndSettle();
      await _pasteAndConfirm(tester, 'Snowman\nImagine - Lennon\nSanta Baby');

      verify(repo.saveSong(any, uid: 'test-user-id')).called(2);
      expect(find.text('Songs (3)'), findsOneWidget);
      expect(find.text('3 songs added'), findsOneWidget);
      final y = {
        for (final t in ['Snowman', 'Imagine', 'Santa Baby'])
          t: tester.getTopLeft(find.text(t)).dy,
      };
      expect(y['Snowman']! < y['Imagine']!, isTrue);
      expect(y['Imagine']! < y['Santa Baby']!, isTrue);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Songs (0)'), findsOneWidget);
      verifyNever(repo.deleteSong(any));
    });
  });
}
