import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/practice_stats_provider.dart';
import 'package:flowgroove/router/branch_stack_observer.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flowgroove/screens/main_shell.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/screens/setlists/setlist_view_screen.dart';
import 'package:flowgroove/screens/songs/songs_list_screen.dart';
import 'package:flowgroove/services/last_practice_context.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/utils/adaptive_text_scale.dart';
import 'package:flowgroove/widgets/bottom_nav_or_action_bar.dart';
import 'package:flowgroove/widgets/menu_items_scope.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/metronome_test_runtime.dart';
import '../helpers/mocks.dart';
import '../helpers/routed_test_harness.dart';
import '../screens/practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;
import '../screens/songs/songs_list_screen_test.dart'
    show createTestSong, createTestUser;

Widget _adaptiveBuilder(BuildContext context, Widget? child) =>
    AdaptiveTextScale(child: child!);

void _useA24(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = const Size(1260, 2800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _expectVisibleLabel(
  WidgetTester tester,
  Finder label, {
  bool checkHitTest = true,
}) {
  final richText = find.descendant(of: label, matching: find.byType(RichText));
  expect(checkHitTest ? richText.hitTestable() : richText, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(richText);
  final text = paragraph.text.toPlainText();
  expect(paragraph.didExceedMaxLines, isFalse, reason: text);
  expect(
    paragraph.getMaxIntrinsicHeight(paragraph.size.width),
    lessThanOrEqualTo(paragraph.size.height + 0.01),
    reason: text,
  );
}

void main() {
  for (final (size, systemScale, factor) in const [
    (Size(320, 800), 1.0, 1.0),
    (Size(360, 800), 1.0, 1.0),
    (Size(400, 800), 1.0, 400 / 360),
    (Size(420, 800), 1.0, 1.15),
    (Size(420, 800), 1.3, 1.15),
    (Size(480, 900), 1.0, 1.15),
    (Size(800, 320), 1.0, 1.0),
  ]) {
    testWidgets(
      'scales text at ${size.width}×${size.height} dp with system scale $systemScale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(systemScale),
              ),
              child: const AdaptiveTextScale(
                child: Text('Sample', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        );

        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('Sample'),
        );
        expect(
          paragraph.textScaler.scale(paragraph.text.style!.fontSize!),
          closeTo(16 * systemScale * factor, 0.001),
        );
      },
    );
  }

  testWidgets('A24 home, songs, setlist view and bottom navigation fit', (
    tester,
  ) async {
    _useA24(tester);
    SharedPreferences.setMockInitialValues({});
    MenuScopeRegistry.reset();
    BranchStackObserver.reset();
    final user = createTestUser();
    final song = createTestSong(ourKey: 'C', ourBPM: 120, tags: ['Rock']);
    final setlist = MockDataHelper.createMockSetlist(
      name: 'Gig Setlist',
      songIds: [song.id],
    );
    final router = createRoutedTestRouter(
      initialLocation: '/main/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => MainShell(navigationShell: shell),
          branches: [
            for (final (name, screen) in const [
              ('home', HomeScreen()),
              ('songs', SongsListScreen()),
              ('bands', SizedBox.shrink()),
              ('setlists', SizedBox.shrink()),
              ('profile', SizedBox.shrink()),
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/main/$name',
                    name: name,
                    builder: (_, _) => screen,
                    routes: [
                      if (name == 'setlists')
                        GoRoute(
                          path: 'view',
                          builder: (_, _) =>
                              SetlistViewScreen(setlist: setlist),
                        ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUserProvider.overrideWith(() => TestAppUserNotifier(user)),
          currentUserProvider.overrideWithValue(const AsyncData(null)),
          songsProvider.overrideWith((ref) => Stream.value([song])),
          bandsProvider.overrideWith((ref) => Stream.value([])),
          setlistsProvider.overrideWith((ref) => Stream.value([setlist])),
          practiceStatsProvider.overrideWith(
            (ref) async => PracticeStats.empty,
          ),
          lastPracticeContextProvider.overrideWith(
            (ref) async => LastPracticeContext(
              songId: song.id,
              title: song.title,
              bpm: song.ourBPM,
              updatedAt: DateTime(2026),
            ),
          ),
          ...buildMetronomeTestOverrides(overrideMetronomeProvider: true),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: MonoPulseTheme.theme,
          builder: _adaptiveBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final label in [
      'Continue',
      'Add song',
      'Add band',
      'Add setlist',
      'Audio note',
      'Tuner',
      'Metronome',
      'Rehearsals',
      'Recorder',
      'Practice',
    ]) {
      _expectVisibleLabel(tester, find.text(label));
    }
    for (final label in ['Home', 'Songs', 'Bands', 'Setlists', 'More']) {
      _expectVisibleLabel(
        tester,
        find.descendant(of: find.byType(NavTab), matching: find.text(label)),
      );
    }

    await tester.tap(find.widgetWithText(NavTab, 'Songs'));
    await tester.pumpAndSettle();
    expect(find.byType(SongsListScreen), findsOneWidget);
    for (final label in ['Filters:', 'Key / BPM', '1 song', song.title]) {
      _expectVisibleLabel(tester, find.text(label));
    }
    expect(tester.takeException(), isNull);

    router.go('/main/setlists/view');
    await tester.pumpAndSettle();
    expect(find.byType(SetlistViewScreen), findsOneWidget);
    _expectVisibleLabel(tester, find.text(setlist.name));
    _expectVisibleLabel(tester, find.text(song.title));
    expect(tester.takeException(), isNull);
  });

  testWidgets('A24 metronome fits', (tester) async {
    _useA24(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
        child: MaterialApp(
          theme: MonoPulseTheme.theme,
          builder: _adaptiveBuilder,
          home: const MetronomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectVisibleLabel(tester, find.text('Metronome'));
    _expectVisibleLabel(tester, find.text('120'));
    _expectVisibleLabel(tester, find.text('BPM'));
    expect(tester.takeException(), isNull);
  });

  group('Song Map', () {
    final fixture = PracticeRegionsScreenFixture();

    testWidgets('A24 transport, keys and pad names fit and can be hit', (
      tester,
    ) async {
      _useA24(tester);
      await fixture.pump(
        tester,
        PracticeRegionsScreenFixture.entry(grid: const AudioGrid(bpm: 120))
            .copyWith(peaks: const [20, 60, 40]),
        theme: MonoPulseTheme.theme,
      );

      // Keep the fixture's provider scope and screen when adding the app builder.
      final scope = tester.widget<ProviderScope>(find.byType(ProviderScope));
      final screen = tester.widget<PracticeRegionsScreen>(
        find.byType(PracticeRegionsScreen),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: scope.overrides,
          child: MaterialApp(
            theme: MonoPulseTheme.theme,
            builder: _adaptiveBuilder,
            home: screen,
          ),
        ),
      );
      await fixture.settleAudio(tester);

      for (final (key, label) in [
        ('play', 'Play'),
        ('loop', 'Loop'),
        ('speed', '100%'),
        ('count-in', 'Count-in'),
        ('click', 'Click'),
        ('click-and-drums', 'Drums'),
        ('song-map-key-Shift', 'Shift'),
        ('song-map-key-Chop', 'Chop'),
        ('song-map-key-Range', 'Range'),
      ]) {
        final control = find.byKey(ValueKey(key));
        expect(control.hitTestable(), findsOneWidget);
        _expectVisibleLabel(
          tester,
          find.descendant(of: control, matching: find.text(label)),
          checkHitTest: false,
        );
      }
      for (final (id, name) in [('verse', 'Verse 2'), ('chorus', 'Chorus')]) {
        final pad = find.byKey(ValueKey('region-pad-$id'));
        expect(pad.hitTestable(), findsOneWidget);
        _expectVisibleLabel(
          tester,
          find.descendant(of: pad, matching: find.text(name)),
        );
      }
      expect(tester.takeException(), isNull);
    });
  });
}
