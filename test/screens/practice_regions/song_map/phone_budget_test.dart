import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_tempo_banner.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

void main() {
  const duration = Duration(seconds: 144);
  const title = 'Inocente — rehearsal recording with a long title';
  const grid = AudioGrid(bpm: 123.5);
  final fixture = PracticeRegionsScreenFixture(duration: duration);
  final zoom = find.byKey(const ValueKey('song-map-zoom'));
  final waveform = find.byKey(const ValueKey('song-map-zoom-waveform'));
  final notes = find.byKey(const ValueKey('recording-notes'));
  final bank = find.byType(SongMapPads);

  SongLabEntry entry(List<AudioRegion> regions) =>
      PracticeRegionsScreenFixture.entry(
        songId: 'song-a',
        grid: grid,
        regions: regions,
      ).copyWith(
        title: title,
        peaks: List.generate(200, (i) => 20 + i % 51),
        notes: const [(ms: 2500, text: 'Listen here')],
      );

  Future<void> pump(WidgetTester tester, SongLabEntry take) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.75
      ..padding = const FakeViewPadding(top: 66, bottom: 66);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await fixture.pump(tester, take, theme: MonoPulseTheme.theme);
  }

  void expectTitleAndRows(WidgetTester tester) {
    final titleText = find.text(title).hitTestable();
    expect(titleText, findsOneWidget);
    expect(tester.getSize(titleText).width, greaterThanOrEqualTo(120));
    expect(tester.widget<Text>(titleText).overflow, TextOverflow.ellipsis);

    final pads = tester.widget<SongMapPads>(bank);
    final columns = SongMapPads.columnsForWidth(tester.getSize(bank).width);
    final children = pads.view.children();
    expect(children.length, greaterThanOrEqualTo(columns * 2));
    final notesTop = tester.getTopLeft(notes).dy;
    final transportTop = tester.getTopLeft(find.byType(SongMapTransport)).dy;
    final rows = <double>[];
    for (final region in children.take(columns * 2)) {
      final pad = find.byKey(ValueKey('region-pad-${region.id}'));
      final rect = tester.getRect(pad);
      expect(pad.hitTestable(), findsOneWidget);
      expect(rect.height, 64);
      expect(rect.bottom, lessThanOrEqualTo(notesTop));
      expect(rect.bottom, lessThanOrEqualTo(transportTop));
      rows.add(rect.top);
    }
    expect(rows.take(columns), everyElement(rows.first));
    expect(rows.skip(columns), everyElement(rows.last));
    expect(rows.last, greaterThan(rows.first));
  }

  void expectThinBars(WidgetTester tester, {required bool pcm}) {
    final canvas = TestRecordingCanvas();
    final size = tester.getSize(waveform);
    expect(size.height, 64);
    tester.widget<CustomPaint>(waveform).painter!.paint(canvas, size);
    final bars = [
      for (final call in canvas.invocations)
        if (call.invocation.memberName == #drawLine)
          call.invocation.positionalArguments[2] as Paint,
    ];
    expect(bars, isNotEmpty);
    expect(
      bars.map((bar) => bar.strokeWidth),
      everyElement(lessThanOrEqualTo(3)),
    );
    if (pcm) expect(bars.length, (size.width / 3).ceil());
  }

  void expectOpenSectionOutlined(
    WidgetTester tester,
    String id, {
    bool playing = false,
  }) {
    final block = find.byKey(ValueKey('song-map-section-$id'));
    final decoration =
        tester.widget<Container>(block).decoration! as BoxDecoration;
    final side = (decoration.border! as Border).top;
    expect(side.width, 3);
    expect(
      side.color,
      playing
          ? MonoPulseColors.accentOrange
          : tester.element(block).mp.textPrimary,
    );
  }

  void stubPcm(Int16List? pcm) {
    final original = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm = (
      _, {
      required sampleRate,
      required durationMs,
    }) async => pcm;
    addTearDown(() => PracticeRegionsScreen.decodePcm = original);
  }

  testWidgets('tempo banner leaves room for two rows in both banks', (
    tester,
  ) async {
    stubPcm(null);
    final regions = [
      for (var i = 0; i < 16; i++)
        AudioRegion(
          id: 'r$i',
          name: switch (i) {
            0 => 'Intro',
            1 => 'Part B',
            >= 2 && < 10 => 'Chorus part ${i - 1}',
            _ => 'Section $i',
          },
          section: i >= 2 && i < 10 ? 'Chorus 1' : null,
          startMs: i * 9000,
          endMs: (i + 1) * 9000,
        ),
    ];
    await pump(tester, entry(regions));
    expect(find.byType(SongMapTempoBanner).hitTestable(), findsOneWidget);
    expectTitleAndRows(tester);
    expectThinBars(tester, pcm: false);
    expectOpenSectionOutlined(tester, 'r0');

    final shift = find.byKey(const ValueKey('song-map-key-Shift'));
    await tester.tap(shift);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('region-pad-r2')));
    await tester.pumpAndSettle();
    final name = find.text('C · Chorus 1').hitTestable();
    expect(name, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
      isFalse,
    );
    expect(
      tester.getRect(name).bottom,
      lessThanOrEqualTo(tester.getRect(shift).top),
    );
    expectTitleAndRows(tester);
    expectThinBars(tester, pcm: false);
    expectOpenSectionOutlined(tester, 'r2');

    await tester.tap(find.byKey(const ValueKey('region-pad-r2')));
    await fixture.settleAudio(tester);
    await tester.tap(find.byKey(const ValueKey('play')));
    await fixture.settleAudio(tester);
    expectOpenSectionOutlined(tester, 'r2', playing: true);

    await tester.tap(find.text('Keep'));
    await fixture.settleAudio(tester);
    expect(find.byType(SongMapTempoBanner), findsNothing);
    expectTitleAndRows(tester);
  });

  testWidgets('analysis review fits two pad rows and draws a PCM envelope', (
    tester,
  ) async {
    const rate = 22050;
    const frequencies = [
      110,
      262,
      392,
      147,
      330,
      220,
      440,
      196,
      294,
      131,
      349,
      165,
    ];
    final pcm = Int16List(rate * duration.inSeconds);
    for (var i = 0; i < pcm.length; i++) {
      final frequency = frequencies[i ~/ (rate * 12)];
      pcm[i] = (4000 * math.sin(2 * math.pi * frequency * i / rate)).round();
    }
    stubPcm(pcm);
    await pump(tester, entry(const []));
    await tester.tap(find.text('Analyze song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze'));
    final review = find.textContaining('sections found · check, then Done');
    for (var i = 0; i < 20 && review.evaluate().isEmpty; i++) {
      await fixture.settleAudio(tester);
    }
    expect(review.hitTestable(), findsOneWidget);
    expect(find.byType(SongMapTempoBanner).hitTestable(), findsOneWidget);
    final notesHeader = find.text('Notes · 1');
    expect(notesHeader.hitTestable(), findsOneWidget);
    expect(tester.getSize(notes).height, 48);
    expectTitleAndRows(tester);
    await tester.tap(notesHeader);
    await tester.pumpAndSettle();
    expect(find.text('Listen here').hitTestable(), findsOneWidget);
    expectTitleAndRows(tester);
    await tester.tap(find.byTooltip('Collapse notes'));
    await tester.pumpAndSettle();
    expect(notesHeader.hitTestable(), findsOneWidget);
    expectThinBars(tester, pcm: true);

    final view = tester.widget<SongMapTimeline>(zoom).view;
    final first = view.sections.first;
    final next = view.sections[1];
    expectOpenSectionOutlined(tester, first.id);
    final nextBlock = find.byKey(ValueKey('song-map-section-${next.id}'));
    await tester.tap(nextBlock);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(tester.widget<SongMapTimeline>(zoom).viewport.startMs, next.startMs);
    expectOpenSectionOutlined(tester, next.id);
    expectTitleAndRows(tester);

    final mapScroll = find.ancestor(
      of: zoom,
      matching: find.byType(Scrollable),
    );
    final scroll = tester.state<ScrollableState>(mapScroll).position;
    final reviewTop = tester.getTopLeft(review);
    expect(scroll.maxScrollExtent, greaterThan(0));
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(review), reviewTop);
    expect(find.text('Done').hitTestable(), findsOneWidget);
    expect(find.text('Discard').hitTestable(), findsOneWidget);
  });
}
