import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

Future<void> _pumpPractice(
  WidgetTester tester, {
  bool review = false,
  bool noAudio = false,
  bool beats = false,
}) async {
  final decode = PracticeRegionsScreen.decodePcm;
  PracticeRegionsScreen
      .decodePcm = (_, {required sampleRate, required durationMs}) async {
    // noAudio: analysis fails with 'Missing audio' (the Manual setup path).
    final pcm = Int16List(noAudio ? 0 : sampleRate * durationMs ~/ 1000);
    if (review) {
      const frequencies = [110, 262, 392, 147, 330, 220, 440, 196, 294, 131];
      for (var i = 0; i < pcm.length; i++) {
        final frequency = frequencies[i * frequencies.length ~/ pcm.length];
        pcm[i] = (4000 * math.sin(2 * math.pi * frequency * i / sampleRate))
            .round();
      }
      if (beats) {
        // A click on every beat of a 170 BPM take, so the detector finds it.
        final step = sampleRate * 60 / 170;
        for (var t = sampleRate * 0.3; t + 220 < pcm.length; t += step) {
          for (var b = 0; b < 220; b++) {
            pcm[t.round() + b] = b.isEven ? 20000 : -20000;
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
      regions: review ? const [] : _regions,
      grid: AudioGrid(bpm: review ? 169.6 : 170),
    ).copyWith(title: 'First Song', peaks: const [25, 60, 40, 80, 35]),
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
  await _pumpPractice(tester);
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
  await _pumpPractice(tester);
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
  await _pumpPractice(tester, review: true);
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
  await _pumpPractice(tester, review: true, beats: true);
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
  await _pumpPractice(tester);
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
