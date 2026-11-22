import 'dart:async';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  const regionLength = 16000;
  final fixture = PracticeRegionsScreenFixture(
    duration: const Duration(milliseconds: 8 * regionLength),
  );
  final entry = PracticeRegionsScreenFixture.entry(
    songId: 'saved-song',
    grid: const AudioGrid(bpm: 120),
    regions: [
      for (var i = 0; i < 8; i++)
        AudioRegion(
          id: 'r$i',
          name: 'Region ${String.fromCharCode(65 + i)}',
          startMs: i * regionLength,
          endMs: (i + 1) * regionLength,
        ),
    ],
  ).copyWith(title: 'Back to Black', peaks: const [20, 60, 40]);
  final play = _key('play');
  final loop = _key('loop');
  final firstPad = _key('region-pad-r0');
  final zoom = _key('song-map-zoom');
  late AudioPlayer player;

  setUp(() {
    final decodePcm = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm = (
      _, {
      required sampleRate,
      required durationMs,
    }) async => null;
    addTearDown(() => PracticeRegionsScreen.decodePcm = decodePcm);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    player = AudioPlayer();
    await fixture.pump(tester, entry, player: player);
  }

  void expectTransport(WidgetTester tester, bool playing) {
    expect(player.playing, playing);
    final label = player.playing ? 'Pause' : 'Play';
    expect(
      find.descendant(of: play, matching: find.text(label)),
      findsOneWidget,
    );
    expect(tester.getSemantics(play).label, label);
  }

  Future<void> press(WidgetTester tester, Finder control) async {
    expect(control.hitTestable(), findsOneWidget);
    await tester.tap(control);
    await fixture.settleAudio(tester);
  }

  for (final loopSelection in [true, false]) {
    testWidgets(
      'resumes repeatedly on ${loopSelection ? 'a saved loop' : 'the whole song'}',
      (tester) async {
        await pump(tester);
        expectTransport(tester, false);
        if (loopSelection) {
          await press(tester, firstPad);
          expectTransport(tester, false);
          await press(tester, loop);
          expectTransport(tester, false);
          await press(tester, loop);
          expectTransport(tester, false);
          expect(tester.widget<FilterChip>(loop).selected, isTrue);
        }
        expect(tester.widget<SongMapTimeline>(zoom).positionMs, 0);

        await press(tester, play);
        expectTransport(tester, true);
        expect(fixture.platformPlaying, isTrue);
        for (var i = 0; i < 4; i++) {
          final before = 11000 + i * 1000;
          fixture.emitPosition(
            before,
            reportedDuration: Duration(milliseconds: before),
          );
          await fixture.settleAudio(tester);
          expect(tester.widget<SongMapTimeline>(zoom).positionMs, before);
          await press(tester, play);
          expectTransport(tester, false);
          expect(fixture.platformPlaying, isFalse);
          await press(tester, play);
          expectTransport(tester, true);
          expect(fixture.platformPlaying, isTrue);
          expect(tester.widget<SongMapTimeline>(zoom).positionMs, before);
          final resumed = before + 500;
          fixture.emitPosition(
            resumed,
            reportedDuration: Duration(milliseconds: resumed),
          );
          await fixture.settleAudio(tester);
          expect(tester.widget<SongMapTimeline>(zoom).positionMs, resumed);
        }
      },
    );
  }

  testWidgets('waits for a pending platform pause before resuming', (
    tester,
  ) async {
    await pump(tester);
    await press(tester, firstPad);
    await press(tester, play);
    final release = fixture.holdNextPause();
    await press(tester, play);
    expectTransport(tester, false);
    await press(tester, play);
    expectTransport(tester, false);
    release.complete();
    await fixture.settleAudio(tester);
    expectTransport(tester, true);
    expect(fixture.platformPlaying, isTrue);
  });

  testWidgets('reflects player state events during and after a clip load', (
    tester,
  ) async {
    await pump(tester);
    final release = fixture.holdNextLoad();
    await press(tester, firstPad);
    unawaited(player.play());
    await fixture.settleAudio(tester);
    expectTransport(tester, true);
    release.complete();
    await fixture.settleAudio(tester);
    expectTransport(tester, true);
  });

  testWidgets('Play during a clip change keeps the new clip playing', (
    tester,
  ) async {
    await pump(tester);
    await press(tester, firstPad);
    await press(tester, play);
    final release = fixture.holdNextLoad();
    await press(tester, _key('region-pad-r1'));
    expectTransport(tester, false);
    await press(tester, play);
    expectTransport(tester, false);
    release.complete();
    await fixture.settleAudio(tester);
    expectTransport(tester, true);
    expect(fixture.platformPlaying, isTrue);
  });

  testWidgets('only shows Looping when Loop is selected', (tester) async {
    await pump(tester);
    await press(tester, firstPad);
    expect(find.text('Looping Region A'), findsOneWidget);
    await press(tester, loop);
    expect(tester.widget<FilterChip>(loop).selected, isFalse);
    expect(find.textContaining('Looping'), findsNothing);
    await press(tester, loop);
    expect(find.text('Looping Region A'), findsOneWidget);
  });

  testWidgets('aligns the bank name and keys with the Chop label centred', (
    tester,
  ) async {
    await pump(tester);
    final top = tester.getTopLeft(find.text('Sections')).dy;
    final chop = _key('song-map-key-Chop');
    for (final label in ['Shift', 'Chop', 'Range']) {
      expect(tester.getTopLeft(_key('song-map-key-$label')).dy, top);
    }
    final chopRect = tester.getRect(chop);
    final chopLabel = find.text('Chop');
    expect(tester.getCenter(chopLabel), chopRect.center);
    await press(tester, firstPad);
    await press(tester, play);
    fixture.emitPosition(
      8000,
      reportedDuration: const Duration(milliseconds: 8000),
    );
    await fixture.settleAudio(tester);
    await press(tester, chop);
    expect(
      tester.widget<SongMapPads>(find.byType(SongMapPads)).chopLit,
      isTrue,
    );
    expect(tester.getRect(chop), chopRect);
    expect(tester.getCenter(chopLabel), chopRect.center);
  });
}
