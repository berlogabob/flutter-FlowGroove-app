import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _pad(String id) => _key('region-pad-$id');

void main() {
  const duration = Duration(seconds: 40);
  const sectionMs = 4000;
  final fixture = PracticeRegionsScreenFixture(duration: duration);
  final regions = List.generate(
    10,
    (i) => AudioRegion(
      id: 'r$i',
      name: i == 0 ? 'Intro 1 a' : 'Part ${String.fromCharCode(65 + i)}',
      section: i == 0 ? 'Intro' : null,
      startMs: i * sectionMs,
      endMs: (i + 1) * sectionMs,
    ),
  );
  final entry = PracticeRegionsScreenFixture.entry(
    songId: 'saved-song',
    grid: const AudioGrid(bpm: 120),
    regions: regions,
  ).copyWith(peaks: const [25, 60, 40, 80, 35]);
  final overview = _key('song-map-overview');
  final zoom = _key('song-map-zoom');
  final waveform = _key('song-map-zoom-waveform');
  final playhead = find.descendant(
    of: zoom,
    matching: _key('song-map-playhead'),
  );
  final pads = find.byType(SongMapPads);

  Future<void> press(WidgetTester tester, Finder control) async {
    expect(control.hitTestable(), findsOneWidget);
    await tester.tap(control);
    await fixture.settleAudio(tester);
  }

  void expectPlaying(WidgetTester tester, int index) {
    expect(tester.widget<SongMapPads>(pads).playingIndex, index);
    for (final (i, region) in regions.indexed) {
      final block = tester.widget<Container>(
        _key('song-map-section-${region.id}'),
      );
      final border = (block.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color == MonoPulseColors.accentOrange, i == index);
    }
    expect(playhead, findsOneWidget);
    final x = tester.getCenter(playhead).dx;
    final bounds = tester.getRect(waveform);
    expect(x, greaterThanOrEqualTo(bounds.left));
    expect(x, lessThan(bounds.right));
  }

  Future<void> reportPosition(WidgetTester tester, int ms) async {
    // Cap just_audio's clock extrapolation at this event's position.
    fixture.emitPosition(ms, reportedDuration: Duration(milliseconds: ms));
    await fixture.settleAudio(tester);
  }

  for (final (phone, size, theme) in [
    ('P30', const Size(1080, 2340), MonoPulseTheme.theme),
    ('A24', const Size(1260, 2800), MonoPulseTheme.lightTheme),
  ]) {
    Future<void> pump(
      WidgetTester tester, {
      Future<Int16List?>? decodedPcm,
    }) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 3
        ..padding = const FakeViewPadding(top: 72, bottom: 72);
      addTearDown(tester.view.reset);
      final original = PracticeRegionsScreen.decodePcm;
      PracticeRegionsScreen.decodePcm = (
        _, {
        required sampleRate,
        required durationMs,
      }) async => decodedPcm ?? Int16List(sampleRate * durationMs ~/ 1000);
      addTearDown(() => PracticeRegionsScreen.decodePcm = original);
      await fixture.pump(tester, entry, theme: theme);
    }

    testWidgets('$phone keeps the saved map layout stable', (tester) async {
      await pump(tester);
      final time = find
          .ancestor(
            of: find.textContaining(RegExp(r'^(\d+:\d+ / 0:40|Bar \d+)$')),
            matching: find.byType(Row),
          )
          .first;
      final common = {
        'overview': overview,
        'zoom': zoom,
        'waveform': waveform,
        'Shift': _key('song-map-key-Shift'),
        'Chop': _key('song-map-key-Chop'),
        'Range': _key('song-map-key-Range'),
        'Notes': _key('recording-notes'),
        'Notes header': find.text('Notes'),
        'time row': time,
        'transport': find.byType(SongMapTransport),
        for (final key in [
          'play',
          'loop',
          'speed',
          'count-in',
          'click',
          'click-and-drums',
        ])
          key: _key(key),
      };
      final sectionPads = {
        for (final region in regions) region.id: _pad(region.id),
        for (final region in regions)
          '${region.id} subtitle': find.descendant(
            of: _pad(region.id),
            matching: find.text('2 bars'),
          ),
      };
      final baseline = {
        for (final item in {...common, ...sectionPads}.entries)
          item.key: tester.getRect(item.value),
      };

      void expectRects(Map<String, Finder> widgets, String state) {
        for (final item in widgets.entries) {
          expect(
            tester.getRect(item.value),
            baseline[item.key],
            reason: '$state: ${item.key}',
          );
        }
      }

      for (final (key, selected) in [
        ('loop', true),
        ('loop', false),
        ('click', true),
        ('click', false),
        ('click-and-drums', true),
        ('click-and-drums', false),
        ('count-in', true),
        ('count-in', false),
      ]) {
        await press(tester, _key(key));
        expect(tester.widget<FilterChip>(_key(key)).selected, selected);
        expectRects({...common, ...sectionPads}, '$key=$selected');
      }

      await press(tester, _pad('r0'));
      expect(tester.widget<SongMapPads>(pads).selectedIndices, {0});
      expectRects({...common, ...sectionPads}, 'selected');
      await press(tester, _key('play'));
      expectPlaying(tester, 0);
      expectRects({...common, ...sectionPads}, 'playing');
      await press(tester, _key('play'));
      expect(tester.widget<SongMapPads>(pads).playingIndex, isNull);
      expectRects({...common, ...sectionPads}, 'paused');
      await press(tester, _pad('r1'));
      expect(tester.widget<SongMapPads>(pads).selectedIndices, {1});
      expectRects({...common, ...sectionPads}, 'second section selected');
      await press(tester, _pad('r0'));

      await press(tester, _key('song-map-key-Shift'));
      expectRects({...common, ...sectionPads}, 'Shift lit');
      await press(tester, _pad('r0'));
      expect(tester.widget<SongMapPads>(pads).view.sectionIndex, 0);
      expectRects({...common, 'r0': _pad('r0')}, 'inside Intro');
      await press(tester, _key('song-map-key-‹ Song'));
      expectRects({...common, ...sectionPads}, 'back at song level');

      await press(tester, _key('click'));
      await press(tester, _key('play'));
      fixture.startQueuedBacking();
      await tester.pump();
      expectPlaying(tester, 0);
      await press(tester, _pad('r1'));
      expect(tester.widget<SongMapPads>(pads).queuedIndex, 1);
      expectPlaying(tester, 0);
      expectRects({...common, ...sectionPads}, 'queued');
    });

    testWidgets('$phone loop overshoot keeps playback in Intro', (
      tester,
    ) async {
      await pump(tester);
      final release = fixture.holdNextLoad();
      await press(tester, _pad('r0'));
      expect(tester.widget<FilterChip>(_key('loop')).selected, isTrue);
      await press(tester, _key('play'));
      expect(tester.widget<SongMapPads>(pads).playingIndex, isNull);
      release.complete();
      await fixture.settleAudio(tester);
      expectPlaying(tester, 0);
      await reportPosition(tester, 0);
      final startX = tester.getCenter(playhead).dx;

      await reportPosition(tester, sectionMs - 20);
      expectPlaying(tester, 0);
      expect(tester.getCenter(playhead).dx, greaterThan(startX));

      await reportPosition(tester, sectionMs + 60);
      expectPlaying(tester, 0);
      expect(tester.widget<SongMapTimeline>(zoom).positionMs, 0);
      expect(tester.getCenter(playhead).dx, startX);

      await reportPosition(tester, 15);
      expectPlaying(tester, 0);
      expect(tester.widget<SongMapTimeline>(zoom).positionMs, 15);
    });

    testWidgets('$phone ignores stale positions during a clip change', (
      tester,
    ) async {
      await pump(tester);
      await press(tester, _pad('r0'));
      await press(tester, _key('play'));
      await reportPosition(tester, 1700);
      expectPlaying(tester, 0);
      final overviewPlayhead = find.descendant(
        of: overview,
        matching: _key('song-map-playhead'),
      );
      final before = tester.getRect(overviewPlayhead);
      final zoomBefore = tester.getRect(playhead);
      final release = fixture.holdNextLoad();
      await press(tester, _pad('r1'));
      expect(tester.getRect(playhead), zoomBefore);
      await reportPosition(tester, sectionMs + 60);
      expect(tester.getRect(overviewPlayhead), before);
      expectPlaying(tester, 0);
      expect(tester.getRect(playhead), zoomBefore);

      release.complete();
      await fixture.settleAudio(tester);
      expectPlaying(tester, 1);
    });

    testWidgets('$phone draws a contiguous saved waveform until PCM arrives', (
      tester,
    ) async {
      final decoded = Completer<Int16List?>();
      await pump(tester, decodedPcm: decoded.future);
      await press(tester, _pad('r1'));
      final before = tester.getRect(waveform);

      List<({double x, double width, double height})> strokes() {
        final canvas = TestRecordingCanvas();
        tester
            .widget<CustomPaint>(waveform)
            .painter!
            .paint(canvas, before.size);
        return [
          for (final call in canvas.invocations)
            if (call.invocation.memberName == #drawLine)
              (
                x: (call.invocation.positionalArguments[0] as Offset).dx,
                width: (call.invocation.positionalArguments[2] as Paint)
                    .strokeWidth,
                height:
                    (call.invocation.positionalArguments[1] as Offset).dy -
                    (call.invocation.positionalArguments[0] as Offset).dy,
              ),
        ];
      }

      final coarse = strokes();
      expect(coarse.first.x, lessThanOrEqualTo(coarse.first.width / 2));
      expect(
        coarse.last.x + coarse.last.width / 2,
        greaterThanOrEqualTo(before.width),
      );
      for (var i = 1; i < coarse.length; i++) {
        expect(
          coarse[i].x - coarse[i - 1].x,
          lessThanOrEqualTo((coarse[i - 1].width + coarse[i].width) / 2),
        );
      }

      const rate = 22050;
      final pcm = Int16List(rate * duration.inSeconds)
        ..fillRange(4 * rate, 8 * rate, 12000);
      decoded.complete(pcm);
      await fixture.settleAudio(tester);
      expect(tester.getRect(waveform), before);
      expect(tester.widget<SongMapTimeline>(zoom).pcm, same(pcm));
      final decodedStrokes = strokes();
      expect(decodedStrokes, hasLength((before.width / 3).ceil()));
      expect(
        decodedStrokes.map((stroke) => stroke.height),
        everyElement(greaterThan(before.height * 0.9)),
      );
    });
  }
}
