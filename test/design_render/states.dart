import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../screens/practice_regions_screen_test.dart';

late PracticeRegionsScreenFixture practiceFixture;
late ThemeMode stateTheme;

const _regions = [
  AudioRegion(id: 'a', name: 'Intro', startMs: 0, endMs: 12706),
  AudioRegion(id: 'b', name: 'Part B 1', startMs: 12706, endMs: 24000),
  AudioRegion(id: 'c', name: 'Chorus 1', startMs: 24000, endMs: 40941),
  AudioRegion(id: 'd', name: 'Part D 1', startMs: 40941, endMs: 63529),
  AudioRegion(id: 'e', name: 'Part E 1', startMs: 63529, endMs: 74824),
  AudioRegion(id: 'f', name: 'Bridge 1', startMs: 74824, endMs: 91765),
];

Future<void> _pumpPractice(WidgetTester tester) async {
  final decode = PracticeRegionsScreen.decodePcm;
  PracticeRegionsScreen.decodePcm = (
    _, {
    required sampleRate,
    required durationMs,
  }) async => Int16List(sampleRate * durationMs ~/ 1000);
  addTearDown(() => PracticeRegionsScreen.decodePcm = decode);
  await practiceFixture.pump(
    tester,
    PracticeRegionsScreenFixture.entry(
      regions: _regions,
      grid: const AudioGrid(bpm: 170),
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

final kStates = <String, Future<void> Function(WidgetTester)>{
  'practice_regions': _pumpPractice,
  'song_map_song': _songMapSong,
  'song_map_song_light': _songMapSong,
  'song_map_part': _songMapPart,
  'song_map_part_light': _songMapPart,
};
