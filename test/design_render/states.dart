import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/mocks.dart';
import '../screens/practice_regions_screen_test.dart';

late PracticeRegionsScreenFixture practiceFixture;
late ThemeMode stateTheme;

const _regions = [
  AudioRegion(id: 'a', name: 'Intro', startMs: 0, endMs: 12706),
  AudioRegion(id: 'b', name: 'Part B 1', startMs: 12706, endMs: 24000),
  // Chorus 1 has three 4-bar parts (a b c), as in the frames.
  AudioRegion(
    id: 'c',
    name: 'Chorus 1',
    startMs: 24000,
    endMs: 29647,
    sectionId: 'c',
    section: 'Chorus 1',
  ),
  AudioRegion(
    id: 'c2',
    name: 'Chorus 1',
    startMs: 29647,
    endMs: 35294,
    sectionId: 'c',
    section: 'Chorus 1',
  ),
  AudioRegion(
    id: 'c3',
    name: 'Chorus 1',
    startMs: 35294,
    endMs: 40941,
    sectionId: 'c',
    section: 'Chorus 1',
  ),
  AudioRegion(id: 'd', name: 'Part D 1', startMs: 40941, endMs: 63529),
  AudioRegion(id: 'e', name: 'Part E 1', startMs: 63529, endMs: 74824),
  AudioRegion(id: 'f', name: 'Bridge 1', startMs: 74824, endMs: 91765),
];

// The frames' whole map, 118 bars at 170 BPM; Intro is two parts, 4 + 5 bars.
const _fullRegions = [
  AudioRegion(
    id: 'a',
    name: 'Intro',
    startMs: 0,
    endMs: 5647,
    sectionId: 'a',
    section: 'Intro',
  ),
  AudioRegion(
    id: 'a2',
    name: 'Intro',
    startMs: 5647,
    endMs: 12706,
    sectionId: 'a',
    section: 'Intro',
  ),
  AudioRegion(id: 'b', name: 'Part B 1', startMs: 12706, endMs: 24000),
  AudioRegion(
    id: 'c',
    name: 'Chorus 1',
    startMs: 24000,
    endMs: 29647,
    sectionId: 'c',
    section: 'Chorus 1',
  ),
  AudioRegion(
    id: 'c2',
    name: 'Chorus 1',
    startMs: 29647,
    endMs: 35294,
    sectionId: 'c',
    section: 'Chorus 1',
  ),
  AudioRegion(
    id: 'c3',
    name: 'Chorus 1',
    startMs: 35294,
    endMs: 40941,
    sectionId: 'c',
    section: 'Chorus 1',
  ),
  AudioRegion(id: 'd', name: 'Part D 1', startMs: 40941, endMs: 63529),
  AudioRegion(id: 'e', name: 'Part E 1', startMs: 63529, endMs: 74824),
  AudioRegion(id: 'c4', name: 'Chorus 2', startMs: 74824, endMs: 91765),
  AudioRegion(id: 'd2', name: 'Part D 2', startMs: 91765, endMs: 114353),
  AudioRegion(id: 'f', name: 'Bridge 1', startMs: 114353, endMs: 131294),
  AudioRegion(id: 'f2', name: 'Bridge 2', startMs: 131294, endMs: 136941),
  AudioRegion(id: 'd3', name: 'Part D 3', startMs: 136941, endMs: 166588),
];

Future<void> _pumpPractice(
  WidgetTester tester, {
  bool review = false,
  bool noAudio = false,
  bool beats = false,
  bool full = false,
  double reviewBpm = 170,
  int? songBpm,
}) async {
  final decode = PracticeRegionsScreen.decodePcm;
  PracticeRegionsScreen
      .decodePcm = (_, {required sampleRate, required durationMs}) async {
    // noAudio: analysis fails with 'Missing audio' (the Manual setup path).
    // review: the frames' song, 118 bars: a quiet Intro (A) of 11 bars (the analyzer
    // reads 10; 8 + 2, never a 1-bar tail part), then
    // B C D E C D F F D in 8 12 16 8 12 16 12 4 19 bars, one tone per letter,
    // clicks on every beat from 0.3 s. Shorter than the player's duration.
    const letters = 'ABCDECDFFD';
    const bars = [11, 8, 12, 16, 8, 12, 16, 12, 4, 19];
    const tones = {
      'A': [110.0],
      'B': [262.0, 392.0],
      'C': [392.0, 494.0, 587.0],
      'D': [147.0, 220.0],
      'E': [330.0, 698.0, 880.0],
      'F': [220.0, 277.0, 1318.0],
    };
    final bar = sampleRate * 240 / reviewBpm;
    final length = noAudio
        ? 0
        : review
        ? (sampleRate * 0.3 + 118 * bar).round()
        : sampleRate * durationMs ~/ 1000;
    final pcm = Int16List(length);
    if (review) {
      var edge = sampleRate * 0.3;
      for (var s = 0; s < letters.length; s++) {
        final from = edge.round();
        edge += bars[s] * bar;
        final to = math.min(edge.round(), pcm.length);
        final volume = s == 0 ? 0.05 : 1;
        for (var i = from; i < to; i++) {
          var v = 0.0;
          for (final f in tones[letters[s]]!) {
            v += math.sin(2 * math.pi * f * i / sampleRate);
          }
          pcm[i] = (volume * 3000 * v).round();
        }
      }
      if (beats) {
        final step = sampleRate * 60 / reviewBpm;
        for (var t = sampleRate * 0.3; t + 220 < pcm.length; t += step) {
          final volume = t < sampleRate * 0.3 + bars[0] * bar ? 0.05 : 1;
          for (var b = 0; b < 220; b++) {
            pcm[t.round() + b] = (volume * (b.isEven ? 20000 : -20000)).round();
          }
        }
      }
    }
    return pcm;
  };
  addTearDown(() => PracticeRegionsScreen.decodePcm = decode);
  await practiceFixture.pump(
    tester,
    PracticeRegionsScreenFixture.entry(
      songId: songBpm == null ? '_inbox' : 'song1',
      regions: review
          ? const []
          : full
          ? _fullRegions
          : _regions,
      grid: AudioGrid(bpm: review ? 169.6 : 170),
    ).copyWith(title: 'First Song', peaks: const [25, 60, 40, 80, 35]),
    overrides: [
      if (songBpm != null)
        songsProvider.overrideWith(
          (ref) => Stream.value([
            MockDataHelper.createMockSong(
              id: 'song1',
              title: 'Inocente',
              originalBPM: songBpm,
              ourBPM: songBpm,
            ),
          ]),
        ),
    ],
    theme: stateTheme == ThemeMode.light
        ? MonoPulseTheme.lightTheme
        : MonoPulseTheme.theme,
  );
  final app = tester.widget(find.byType(ProviderScope).first);
  await tester.pumpWidget(
    RepaintBoundary(key: const Key('render-boundary'), child: app),
  );
  await practiceFixture.settleAudio(tester);
}

Future<void> _songMapSong(WidgetTester tester) async {
  await _pumpPractice(tester);
  await tester.tap(find.byKey(const ValueKey('play')));
  await practiceFixture.settleAudio(tester);
  practiceFixture.emitPosition(30000);
  await practiceFixture.settleAudio(tester);
  expect(
    tester.widget<SongMapTransport>(find.byType(SongMapTransport)).playing,
    isTrue,
  );
}

Future<void> _songMapPart(WidgetTester tester) async {
  await _pumpPractice(tester, full: true);
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('song-map-overview')),
      matching: find.byKey(const ValueKey('song-map-section-c')),
    ),
  );
  await tester.pumpAndSettle();
  await tester.longPress(find.byKey(const ValueKey('song-map-pad-f')));
  await tester.pumpAndSettle();
  expect(find.text('Rename section'), findsOneWidget);
}

Future<void> _songMapPlaying(WidgetTester tester) async {
  await _pumpPractice(tester, full: true);
  await tester.tap(find.byKey(const ValueKey('play')));
  await practiceFixture.settleAudio(tester);
  practiceFixture.emitPosition(50824);
  await practiceFixture.settleAudio(tester);
  await tester.tap(find.text('Chop'));
  await tester.pump();
  expect(find.text('Cut at bar 37'), findsOneWidget);
  expect(
    tester.widget<SongMapTransport>(find.byType(SongMapTransport)).playing,
    isTrue,
  );
}

Future<void> _songMapReview(WidgetTester tester) async {
  await _pumpPractice(
    tester,
    review: true,
    beats: true,
    reviewBpm: 169.6,
    songBpm: 170,
  );
  await tester.tap(find.text('Analyze song'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Analyze'));
  final review = find.textContaining(RegExp(r'\d+ found$'));
  for (var i = 0; i < 20 && review.evaluate().isEmpty; i++) {
    await practiceFixture.settleAudio(tester);
  }
  expect(review, findsOneWidget);
  expect(find.text('Keep'), findsOneWidget);
}

Future<void> _analyzeWithBeats(WidgetTester tester) async {
  await _pumpPractice(tester, review: true, beats: true, reviewBpm: 169.6);
  await tester.tap(find.text('Analyze song'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Analyze'));
  final done = find.byKey(const ValueKey('song-map-key-Done'));
  for (var i = 0; i < 20 && done.evaluate().isEmpty; i++) {
    await practiceFixture.settleAudio(tester);
  }
  expect(done, findsOneWidget);
}

Future<void> _songMapTempo(WidgetTester tester) async {
  // Analyze, then hear the other octave: key B of the Tempo row.
  await _analyzeWithBeats(tester);
  await tester.tap(find.byKey(const ValueKey('tempo-b')));
  await practiceFixture.settleAudio(tester);
  expect(find.text('170 BPM'), findsOneWidget);
}

Future<void> _songMapTempoSheet(WidgetTester tester) async {
  // A saved map: the app-bar tempo chip opens the sheet.
  await _pumpPractice(tester, full: true);
  await tester.tap(find.byKey(const ValueKey('tempo-chip')));
  await tester.pumpAndSettle();
  expect(find.text('Tempo'), findsOneWidget);
}

Future<void> _songMapSection(WidgetTester tester) async {
  // Section level: Shift + pad C opens Chorus 1 (parts bank, Song key back).
  await _pumpPractice(tester);
  await tester.tap(find.text('Shift'));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('song-map-pad-c')));
  await tester.pumpAndSettle();
  expect(find.text('C · Chorus 1'), findsOneWidget);
}

Future<void> _replaceSections(WidgetTester tester) async {
  // Analysis fails on a mapped song -> snackbar 'Manual setup' -> the real
  // 'Replace N sections?' dialog (practice_regions_screen.dart _manualSetup).
  await _pumpPractice(tester, noAudio: true);
  // Mapped song: analysis starts from the app-bar menu's 'analyze' entry.
  tester
      .widget<PopupMenuButton<String>>(
        find.byWidgetPredicate((w) => w is PopupMenuButton<String>).first,
      )
      .onSelected!('analyze');
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Analyze'));
  final action = find.text('Manual setup');
  for (var i = 0; i < 20 && action.evaluate().isEmpty; i++) {
    await practiceFixture.settleAudio(tester);
  }
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.text('Replace ${_regions.length} sections?'), findsOneWidget);
}

final kStates = <String, Future<void> Function(WidgetTester)>{
  'practice_regions_replace_n_sections': _replaceSections,
  'song_map_section': _songMapSection,
  'song_map_section_light': _songMapSection,
  'practice_regions': _pumpPractice,
  'song_map_song': _songMapSong,
  'song_map_song_light': _songMapSong,
  'song_map_part': _songMapPart,
  'song_map_part_light': _songMapPart,
  'song_map_playing': _songMapPlaying,
  'song_map_playing_light': _songMapPlaying,
  'song_map_review': _songMapReview,
  'song_map_review_light': _songMapReview,
  'song_map_tempo': _songMapTempo,
  'song_map_tempo_light': _songMapTempo,
  'song_map_tempo_sheet': _songMapTempoSheet,
  'song_map_tempo_sheet_light': _songMapTempoSheet,
};
