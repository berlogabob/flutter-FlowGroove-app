import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/screens/concert_mode_screen.dart';
import 'package:flowgroove/widgets/performance_sheet_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/metronome_test_runtime.dart';
import '../helpers/mocks.dart';

void main() {
  group('ConcertModeScreen', () {
    Future<ProviderContainer> pumpConcertMode(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final songs = [
        MockDataHelper.createMockSong(
          id: 'song-1',
          title: 'First song',
          ourBPM: 120,
        ).copyWith(
          sections: [
            Section(
              id: 'verse-1',
              name: 'Verse',
              chordChart: '[C]Hello [G]world',
            ),
          ],
        ),
        MockDataHelper.createMockSong(
          id: 'song-2',
          title: 'Second song',
          ourBPM: 95,
        ),
      ];
      final setlist = MockDataHelper.createMockSetlist(
        songIds: songs.map((song) => song.id).toList(),
      );
      final runtime = MetronomeTestRuntime();
      final container = ProviderContainer(
        overrides: [
          ...runtime.overrides,
          songsProvider.overrideWith((ref) => Stream.value(songs)),
          setlistsProvider.overrideWith((ref) => Stream.value([setlist])),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await runtime.dispose();
      });
      container
          .read(metronomeProvider.notifier)
          .loadSetlistQueue(setlist, availableSongs: songs);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ConcertModeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> unmountConcertMode(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    }

    testWidgets('sheet toggle shows the sheet and hides the BPM readout', (
      tester,
    ) async {
      await pumpConcertMode(tester);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.byType(PerformanceSheetView), findsNothing);

      await tester.tap(find.byTooltip('Lyrics & chords'));
      await tester.pumpAndSettle();

      final sheet = tester.widget<PerformanceSheetView>(
        find.byType(PerformanceSheetView),
      );
      expect(sheet.sections.single.chordChart, '[C]Hello [G]world');
      expect(find.text('120'), findsNothing);
      expect(find.text('BPM'), findsNothing);
      expect(find.byTooltip('Show BPM'), findsOneWidget);
      await unmountConcertMode(tester);
    });

    testWidgets('Next song restores BPM when the next song has no sheet', (
      tester,
    ) async {
      final container = await pumpConcertMode(tester);
      await tester.tap(find.byTooltip('Lyrics & chords'));
      await tester.pumpAndSettle();
      expect(find.byType(PerformanceSheetView), findsOneWidget);

      await tester.tap(find.byTooltip('Next song'));
      await tester.pumpAndSettle();

      expect(container.read(metronomeProvider).activeSong?.id, 'song-2');
      expect(find.text('Second song'), findsOneWidget);
      expect(find.text('95'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.byType(PerformanceSheetView), findsNothing);
      expect(find.byTooltip('Lyrics & chords'), findsNothing);
      expect(find.byTooltip('Show BPM'), findsNothing);
      await unmountConcertMode(tester);
    });

    testWidgets('Previous is disabled on the first song', (tester) async {
      final container = await pumpConcertMode(tester);
      final previous = find.byTooltip('Previous song');
      final button = tester.widget<GestureDetector>(
        find.descendant(of: previous, matching: find.byType(GestureDetector)),
      );
      expect(button.onTap, isNull);

      await tester.tap(previous);
      await tester.pumpAndSettle();

      expect(container.read(metronomeProvider).currentSetlistIndex, 0);
      expect(container.read(metronomeProvider).activeSong?.id, 'song-1');
      expect(find.text('First song'), findsOneWidget);
      await unmountConcertMode(tester);
    });
  });
}
