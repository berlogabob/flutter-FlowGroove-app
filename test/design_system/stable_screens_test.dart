import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/screens/setlists/setlist_view_screen.dart';
import 'package:flowgroove/screens/tuner_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/tuner/transport_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/layout_stability.dart';
import '../helpers/layout_test_tuner.dart';
import '../helpers/metronome_test_runtime.dart';
import '../helpers/mocks.dart';
import '../helpers/routed_test_harness.dart';
import '../screens/practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;
import '../screens/songs/songs_list_screen_test.dart'
    show createTestSong, createTestUser;

void main() {
  final practice = PracticeRegionsScreenFixture(
    duration: const Duration(seconds: 40),
  );
  for (final (phone, physicalSize) in [
    ('1080×2340 phone', const Size(1080, 2340)),
    ('1260×2800 A24', const Size(1260, 2800)),
  ]) {
    group(phone, () {
      void configurePhone(WidgetTester tester) {
        tester.view
          ..physicalSize = physicalSize
          ..devicePixelRatio = 3
          ..padding = const FakeViewPadding(top: 72, bottom: 72);
        addTearDown(tester.view.reset);
      }

      testWidgets('Songs list key filter chip', (tester) async {
        configurePhone(tester);
        await pumpRoutedTestApp(
          tester,
          initialLocation: '/main/songs',
          overrides: [
            appUserProvider.overrideWith(
              () => TestAppUserNotifier(createTestUser()),
            ),
            songsProvider.overrideWith(
              (ref) => Stream.value([
                createTestSong(title: 'First Song', ourKey: 'C'),
                createTestSong(id: '2', title: 'Second Song', ourKey: 'G'),
              ]),
            ),
            bandsProvider.overrideWith((ref) => Stream.value([])),
          ],
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Key / BPM'));
        await tester.pumpAndSettle();
        final chip = find.widgetWithText(FilterChip, 'C');
        expect(tester.widget<FilterChip>(chip).selected, isFalse);
        await expectStableLayout(tester, () async {
          await tester.tap(chip);
          await tester.pumpAndSettle();
        });
        expect(tester.widget<FilterChip>(chip).selected, isTrue);
        expect(find.text('First Song'), findsOneWidget);
        expect(find.text('Second Song'), findsNothing);
      });

      testWidgets(
        'Setlist view updates song metadata and highlights the active row',
        (tester) async {
          configurePhone(tester);
          final first = MockDataHelper.createMockSong(
            id: 's1',
            title: 'First Song',
            artist: 'Band A',
            ourKey: 'Bbm',
            ourBPM: 120,
          );
          final second = MockDataHelper.createMockSong(
            id: 's2',
            title: 'Second Song',
            artist: 'Band B',
            ourKey: 'G',
            ourBPM: 90,
          );
          final setlist = MockDataHelper.createMockSetlist(
            id: 'setlist-1',
            name: 'Gig Setlist',
            songIds: ['s1', 's2'],
          );
          final songs = StreamController<List<Song>>();
          addTearDown(songs.close);
          songs.add([first, second]);
          final container = ProviderContainer(
            overrides: [
              appUserProvider.overrideWith(
                () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
              ),
              currentUserProvider.overrideWithValue(const AsyncData(null)),
              canEditProvider.overrideWithValue(true),
              songsProvider.overrideWith((ref) => songs.stream),
              setlistsProvider.overrideWith((ref) => Stream.value([setlist])),
              ...buildMetronomeTestOverrides(overrideMetronomeProvider: true),
            ],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: MonoPulseTheme.theme,
                home: SetlistViewScreen(setlist: setlist),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('120'), findsOneWidget);
          final updated = MockDataHelper.createMockSong(
            id: 's1',
            title: first.title,
            artist: first.artist,
            ourBPM: 8,
          );
          await expectStableLayout(tester, () async {
            songs.add([updated, second]);
            container.read(metronomeProvider.notifier).loadSongTempo(updated);
            await tester.pumpAndSettle();
          });
          expect(find.text('8'), findsOneWidget);
          expect(container.read(metronomeProvider).activeSong?.id, first.id);
        },
      );

      testWidgets('Metronome starts, ticks and stops', (tester) async {
        configurePhone(tester);
        SharedPreferences.setMockInitialValues({});
        final runtime = MetronomeTestRuntime();
        final container = ProviderContainer(overrides: runtime.overrides);
        addTearDown(() async {
          container.dispose();
          await runtime.dispose();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: MonoPulseTheme.theme,
              home: const MetronomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();
        for (final (glyph, playing) in [
          (Icons.play_arrow, true),
          (Icons.pause, false),
        ]) {
          await expectStableLayout(tester, () async {
            final action = find.byIcon(glyph);
            expect(action.hitTestable(), findsOneWidget);
            await tester.tap(action);
            await tester.pumpAndSettle();
          });
          expect(container.read(metronomeProvider).isPlaying, playing);
          if (playing) {
            await expectStableLayout(tester, () async {
              runtime.playback.emitTick(1);
              await tester.pump(const Duration(milliseconds: 150));
            });
          }
        }
      });

      testWidgets('Tuner starts and stops listening', (tester) async {
        configurePhone(tester);
        final tuner = StabilityTuner(TunerMode.listen);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [tunerProvider.overrideWith(() => tuner)],
            child: MaterialApp(
              theme: MonoPulseTheme.theme,
              home: const TunerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final (glyph, active) in [
          (Icons.mic, true),
          (Icons.stop, false),
        ]) {
          final action = find.descendant(
            of: find.descendant(
              of: find.byType(TransportBar),
              matching: find.byType(AnimatedContainer),
            ),
            matching: find.byIcon(glyph),
          );
          await expectStableLayout(tester, () async {
            await tester.tap(action);
            await tester.pumpAndSettle();
          });
          expect(tuner.active, active);
          if (active) {
            await expectStableLayout(tester, () async {
              tuner.detectPitch();
              await tester.pump();
            });
            expect(find.text('F#4'), findsOneWidget);
          }
        }
      });

      testWidgets('Song Map plays, loops, advances and pauses', (tester) async {
        configurePhone(tester);
        final decodePcm = PracticeRegionsScreen.decodePcm;
        PracticeRegionsScreen.decodePcm = (
          _, {
          required sampleRate,
          required durationMs,
        }) async => Int16List(sampleRate * durationMs ~/ 1000);
        addTearDown(() => PracticeRegionsScreen.decodePcm = decodePcm);
        await practice.pump(
          tester,
          PracticeRegionsScreenFixture.entry(grid: const AudioGrid(bpm: 120))
              .copyWith(peaks: const [25, 60, 40, 80, 35]),
          theme: MonoPulseTheme.theme,
        );
        final transport = find.byType(SongMapTransport);
        final allowed = {const ValueKey('song-map-playhead')};
        final loop = find.byKey(const ValueKey('loop'));
        final play = find.byKey(const ValueKey('play'));
        Future<void> tapStable(Finder finder) =>
            expectStableLayout(tester, () async {
              expect(finder.hitTestable(), findsOneWidget);
              await tester.tap(finder);
              await practice.settleAudio(tester);
            }, allowChanged: allowed);

        await tapStable(loop);
        expect(tester.widget<SongMapTransport>(transport).loop, isTrue);
        await tapStable(play);
        expect(tester.widget<SongMapTransport>(transport).playing, isTrue);
        await expectStableLayout(tester, () async {
          practice.emitPosition(1500);
          await practice.settleAudio(tester);
        }, allowChanged: allowed);
        await tapStable(play);
        expect(tester.widget<SongMapTransport>(transport).playing, isFalse);
        await tapStable(loop);
        expect(tester.widget<SongMapTransport>(transport).loop, isFalse);
      });
    });
  }
}
