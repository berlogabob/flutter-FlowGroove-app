import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/repositories/song_repository.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_tempo_row.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_tempo_sheet.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

/// Clicks every beat of [bpm]: the detector reads this tempo (or its half).
Int16List _clicks(double bpm, {int seconds = 20}) {
  const sampleRate = 22050;
  final pcm = Int16List(sampleRate * seconds);
  final step = sampleRate * 60 / bpm;
  var beat = 0;
  for (var t = sampleRate * 0.3; t + 220 < pcm.length; t += step) {
    final value = beat++ % 4 == 0 ? 30000 : 12000;
    for (var b = 0; b < 220; b++) {
      pcm[t.round() + b] = b.isEven ? value : -value;
    }
  }
  return pcm;
}

Song _song(String id, double bpm) => Song(
  id: id,
  title: 'Inocente',
  artist: 'x',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  ourBPM: bpm.round(),
);

class _SongWrites implements SongRepository {
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName.toString());
    return Future<void>.value();
  }
}

void main() {
  group('songMapTempoOptions', () {
    test('without a song BPM offers both octaves, lower first', () {
      expect(songMapTempoOptions(169.6, null), (a: 85, b: 170));
      expect(songMapTempoOptions(85, null), (a: 85, b: 170));
    });

    test('with a song BPM only an octave error qualifies', () {
      expect(songMapTempoOptions(85, 170), (a: 85, b: 170));
      expect(songMapTempoOptions(340, 170), (a: 170, b: 340));
      expect(songMapTempoOptions(86, 170), (a: 86, b: 172));
      expect(songMapTempoOptions(88.5, 170), isNull);
      expect(songMapTempoOptions(170, 170), isNull);
      expect(songMapTempoOptions(null, null), isNull);
    });
  });

  group('SongMapTempoSheet', () {
    var time = DateTime(2026);
    Future<void> open(
      WidgetTester tester, {
      int bpm = 170,
      void Function(SongMapTempoResult?)? onClosed,
    }) async {
      tester.view
        ..physicalSize = const Size(412, 915)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: MonoPulseTheme.theme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => (onClosed ?? (_) {})(
                await showModalBottomSheet<SongMapTempoResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SongMapTempoSheet(
                    bpm: bpm,
                    listen: true,
                    now: () => time,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('keys step the value; Save returns it with Listen', (
      tester,
    ) async {
      SongMapTempoResult? result;
      await open(tester, onClosed: (r) => result = r);
      expect(find.text('Tempo'), findsOneWidget);
      expect(find.text('Tap 4 times'), findsOneWidget);
      expect(find.text('Click over the recording'), findsOneWidget);
      await tester.tap(find.text('÷2'));
      await tester.pump();
      expect(find.text('85'), findsOneWidget);
      await tester.tap(find.text('+1'));
      await tester.tap(find.text('+1'));
      await tester.tap(find.text('-1'));
      await tester.tap(find.text('×2'));
      await tester.pump();
      expect(find.text('172'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tempo-listen')));
      await tester.tap(find.byKey(const ValueKey('tempo-save')));
      await tester.pumpAndSettle();
      expect(result, (bpm: 172, listen: false));
    });

    testWidgets('Cancel returns nothing', (tester) async {
      var closed = false;
      SongMapTempoResult? result;
      await open(
        tester,
        onClosed: (r) {
          closed = true;
          result = r;
        },
      );
      await tester.tap(find.text('+1'));
      await tester.tap(find.byKey(const ValueKey('tempo-cancel')));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    });

    testWidgets('Tap sets the average of the last 4 taps', (tester) async {
      await open(tester, bpm: 100);
      Future<void> tap(int afterMs) async {
        time = time.add(Duration(milliseconds: afterMs));
        await tester.tap(find.byKey(const ValueKey('tempo-tap')));
        await tester.pump();
      }

      await tap(0);
      expect(find.text('100'), findsOneWidget);
      await tap(1000); // a slow start, dropped once 4 taps are in the window
      await tap(500);
      await tap(500);
      await tap(500);
      expect(find.text('120'), findsOneWidget);
      time = time.add(const Duration(seconds: 5)); // a pause starts over
      await tap(0);
      await tap(600);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('2- and 3-digit values move nothing', (tester) async {
      await open(tester, bpm: 99);
      final slot = find.byKey(const ValueKey('tempo-value-slot'));
      final keys = [
        slot,
        find.text('BPM'),
        find.text('×2'),
        find.byKey(const ValueKey('tempo-tap')),
        find.byKey(const ValueKey('tempo-save')),
      ];
      final before = [for (final key in keys) tester.getRect(key)];
      await tester.tap(find.text('+1'));
      await tester.pump();
      expect(find.text('100'), findsOneWidget);
      expect([for (final key in keys) tester.getRect(key)], before);
    });
  });

  group('Song Map review', () {
    final fixture = PracticeRegionsScreenFixture();
    final writes = _SongWrites();
    final tempoKeys = [
      find.byKey(const ValueKey('tempo-a')),
      find.byKey(const ValueKey('tempo-b')),
      find.byKey(const ValueKey('tempo-other')),
    ];

    Future<void> analyze(
      WidgetTester tester, {
      double bpm = 170,
      String songId = '_inbox',
      double? songBpm,
      StreamController<List<Song>>? songs,
      List<AudioRegion> regions = const [],
    }) async {
      writes.calls.clear();
      final decode = PracticeRegionsScreen.decodePcm;
      PracticeRegionsScreen.decodePcm = (
        _, {
        required sampleRate,
        required durationMs,
      }) async => _clicks(bpm);
      addTearDown(() => PracticeRegionsScreen.decodePcm = decode);
      final stream =
          songs?.stream ??
          Stream.value([if (songBpm != null) _song(songId, songBpm)]);
      await fixture.pump(
        tester,
        PracticeRegionsScreenFixture.entry(songId: songId, regions: regions),
        overrides: [
          songsProvider.overrideWith((ref) => stream),
          songRepositoryProvider.overrideWithValue(writes),
        ],
      );
      await fixture.settleAudio(tester);
      await tester.tap(find.text('Analyze song'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze'));
      final done = find.widgetWithText(FilledButton, 'Done');
      for (var i = 0; i < 20 && done.evaluate().isEmpty; i++) {
        await fixture.settleAudio(tester);
      }
      expect(done, findsOneWidget);
    }

    testWidgets('TC1: one row with the section count, Discard and Done', (
      tester,
    ) async {
      await analyze(tester);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.textContaining(RegExp(r'^\d+ sections?$')), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      final row = tester.getSize(find.byType(SongMapReviewRow));
      expect(row.height, SongMapReviewRow.height);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(SongMapReviewRow), findsNothing);
    });

    testWidgets(
      'TC2: A | B | Other of equal fixed size; the detected one is chosen',
      (tester) async {
        await analyze(tester);
        expect(find.text('85'), findsOneWidget);
        expect(find.text('170'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);
        final sizes = [for (final key in tempoKeys) tester.getSize(key)];
        expect(sizes.toSet().length, 1);
        expect(sizes.first.height, SongMapTempoRow.keyHeight);
        expect(find.widgetWithText(FilledButton, '85'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, '170'), findsOneWidget);
      },
    );

    testWidgets('TC2: choosing A sets the grid and the click, not the song', (
      tester,
    ) async {
      await analyze(tester);
      expect(find.text('85'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tempo-a')));
      await fixture.settleAudio(tester);
      expect(find.text('85 BPM'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '85'), findsOneWidget);
      expect(
        tester.widget<SongMapTransport>(find.byType(SongMapTransport)).click,
        isTrue,
      );
      await tester.tap(find.text('Done'));
      await fixture.settleAudio(tester);
      expect(fixture.savedEntries.single.grid!.bpm, 85);
      expect(writes.calls, isEmpty);
    });

    testWidgets('TC2: the song BPM stays after choosing and after Done', (
      tester,
    ) async {
      // The detector folds toward the song's BPM, so the octave question with
      // a song BPM only arises when the BPM is set after the analysis.
      final songs = StreamController<List<Song>>()..add([]);
      addTearDown(songs.close);
      await analyze(tester, bpm: 85, songId: 'song1', songs: songs);
      songs.add([_song('song1', 170)]);
      await fixture.settleAudio(tester);
      expect(find.byKey(const ValueKey('tempo-a')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tempo-b')));
      await fixture.settleAudio(tester);
      int? songBpm() => ProviderScope.containerOf(
        tester.element(find.byType(PracticeRegionsScreen)),
      ).read(songsProvider).value!.single.ourBPM;
      expect(songBpm(), 170);
      await tester.tap(find.text('Done'));
      await fixture.settleAudio(tester);
      expect(writes.calls, isEmpty);
      expect(songBpm(), 170);
      expect(fixture.savedEntries.single.grid!.bpm, 170);
    });

    testWidgets('TC2: selecting the other key changes colour, not geometry', (
      tester,
    ) async {
      await analyze(tester);
      final before = [for (final key in tempoKeys) tester.getRect(key)];
      final chip = tester.getRect(find.byType(Chip));
      await tester.tap(find.byKey(const ValueKey('tempo-a')));
      await fixture.settleAudio(tester);
      expect([for (final key in tempoKeys) tester.getRect(key)], before);
      expect(tester.getRect(find.byType(Chip)), chip);
      await tester.tap(find.byKey(const ValueKey('tempo-b')));
      await fixture.settleAudio(tester);
      expect([for (final key in tempoKeys) tester.getRect(key)], before);
    });

    testWidgets('TC2: the row is hidden when the song BPM agrees', (
      tester,
    ) async {
      await analyze(tester, songId: 'song1', songBpm: 170);
      expect(find.byType(SongMapTempoRow), findsNothing);
    });

    testWidgets('TC3: Other opens the sheet; Save sets the candidate grid', (
      tester,
    ) async {
      await analyze(tester);
      await tester.tap(find.byKey(const ValueKey('tempo-other')));
      await tester.pumpAndSettle();
      expect(find.text('Tempo'), findsOneWidget);
      await tester.tap(find.text('+1'));
      await tester.tap(find.byKey(const ValueKey('tempo-save')));
      await fixture.settleAudio(tester);
      expect(find.text('86 BPM'), findsOneWidget);
      expect(fixture.savedEntries, isEmpty);
      await tester.tap(find.text('Done'));
      await fixture.settleAudio(tester);
      expect(fixture.savedEntries.single.grid!.bpm, 86);
      expect(writes.calls, isEmpty);
    });

    testWidgets('TC3: Cancel changes nothing', (tester) async {
      await analyze(tester);
      await tester.tap(find.byKey(const ValueKey('tempo-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('-1'));
      await tester.tap(find.byKey(const ValueKey('tempo-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('85 BPM'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '85'), findsOneWidget);
    });

    testWidgets('TC3: the BPM chip opens the sheet for a saved map', (
      tester,
    ) async {
      final decode = PracticeRegionsScreen.decodePcm;
      addTearDown(() => PracticeRegionsScreen.decodePcm = decode);
      await fixture.pump(
        tester,
        PracticeRegionsScreenFixture.entry(
          songId: 'song1',
          grid: const AudioGrid(bpm: 120, offsetMs: 40),
        ),
        overrides: [
          songsProvider.overrideWith(
            (ref) => Stream.value([
              Song(
                id: 'song1',
                title: 'x',
                artist: 'x',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                ourBPM: 90,
              ),
            ]),
          ),
          songRepositoryProvider.overrideWithValue(writes),
        ],
      );
      writes.calls.clear();
      await tester.tap(find.text('120 BPM'));
      await tester.pumpAndSettle();
      expect(find.text('Tempo'), findsOneWidget);
      await tester.tap(find.text('+1'));
      await tester.tap(find.byKey(const ValueKey('tempo-save')));
      await fixture.settleAudio(tester);
      final grid = fixture.savedEntries.last.grid!;
      expect((grid.bpm, grid.offsetMs), (121, 40));
      expect(find.text('121 BPM'), findsOneWidget);
      expect(writes.calls, isEmpty);
    });
  });
}
