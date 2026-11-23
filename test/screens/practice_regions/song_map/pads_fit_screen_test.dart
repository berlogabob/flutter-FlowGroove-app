import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_tempo_banner.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

void main() {
  const duration = Duration(minutes: 4);
  final fixture = PracticeRegionsScreenFixture(duration: duration);

  final regions = List.generate(
    8,
    (index) => AudioRegion(
      id: 'legacy-$index',
      name: '',
      startMs: index * 30000,
      endMs: (index + 1) * 30000,
    ),
  );
  final entry = PracticeRegionsScreenFixture.entry(
    songId: 'song-a',
    grid: const AudioGrid(bpm: 123.5),
    regions: regions,
  ).copyWith(peaks: const [20, 60, 40]);

  setUp(() {
    final decodePcm = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm = (
      _, {
      required sampleRate,
      required durationMs,
    }) async => null;
    addTearDown(() => PracticeRegionsScreen.decodePcm = decodePcm);
  });

  testWidgets(
    'eight legacy pads fit above the transport with the tempo banner',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await fixture.pump(tester, entry);

      final banner = find.byType(SongMapTempoBanner);
      expect(
        find.descendant(
          of: banner,
          matching: find.text('Detected tempo 123.5'),
        ),
        findsOneWidget,
      );
      expect(find.text('Stretch to 124').hitTestable(), findsOneWidget);
      expect(find.text('Keep').hitTestable(), findsOneWidget);

      final screen =
          Offset.zero &
          (tester.view.physicalSize / tester.view.devicePixelRatio);
      final transport = tester.getRect(find.byType(SongMapTransport));
      final rects = <Rect>[];
      for (final (index, region) in regions.indexed) {
        final pad = find.byKey(ValueKey('region-pad-${region.id}'));
        final rect = tester.getRect(pad);
        expect(rect.left, greaterThanOrEqualTo(screen.left));
        expect(rect.right, lessThanOrEqualTo(screen.right));
        expect(rect.top, greaterThanOrEqualTo(screen.top));
        expect(rect.bottom, lessThanOrEqualTo(transport.top));
        expect(rect.height, 64);
        rects.add(rect);
        expect(
          find
              .descendant(
                of: pad,
                matching: find.text(
                  'Region ${String.fromCharCode(65 + index)}',
                ),
              )
              .hitTestable(),
          findsOneWidget,
        );
        expect(
          find.descendant(of: pad, matching: find.textContaining(' bars')),
          findsOneWidget,
        );
        // P30: every pad read "Region…"; the whole name must show.
        final name = find.descendant(
          of: pad,
          matching: find.text('Region ${String.fromCharCode(65 + index)}'),
        );
        expect(
          tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
          isFalse,
        );
      }
      for (var i = 0; i < rects.length; i += 2) {
        expect(rects[i].top, rects[i + 1].top);
        expect(rects[i + 1].left, greaterThanOrEqualTo(rects[i].right));
        expect(rects[i].left, rects.first.left);
        expect(rects[i + 1].left, rects[1].left);
        if (i > 0) {
          expect(rects[i].top, greaterThanOrEqualTo(rects[i - 2].bottom));
        }
      }
      expect(find.text('Unnamed'), findsNothing);
      expect(find.textContaining('No notes yet'), findsNothing);
      expect(find.text('at 0:00').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('Notes gives way to two pad rows on a short, narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(350, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await fixture.pump(
      tester,
      entry.copyWith(
        notes: List.generate(10, (i) => (ms: i * 1000, text: 'Note $i')),
      ),
    );

    final notes = find.byKey(const ValueKey('recording-notes'));
    final pads = [
      for (var i = 0; i < 6; i++) find.byKey(ValueKey('region-pad-legacy-$i')),
    ];
    final padScroll = find.descendant(
      of: find.byType(SongMapPads),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(padScroll).position;
    expect(position.maxScrollExtent, greaterThan(0));
    final rects = pads.map(tester.getRect).toList();
    for (var i = 0; i < rects.length; i += 2) {
      expect(rects[i].top, rects[i + 1].top);
      expect(rects[i + 1].left, greaterThanOrEqualTo(rects[i].right));
      if (i > 0) {
        expect(rects[i].top, greaterThanOrEqualTo(rects[i - 2].bottom));
      }
    }

    Future<void> expectPadRows() async {
      for (final (index, pad) in pads.indexed) {
        if (index >= 4) {
          await tester.ensureVisible(pad);
          await tester.pumpAndSettle();
        }
        expect(pad.hitTestable(), findsOneWidget);
        final rect = tester.getRect(pad);
        final viewport = tester.getRect(padScroll);
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(rect.bottom, lessThanOrEqualTo(tester.getRect(notes).top));
      }
      position.jumpTo(0);
      await tester.pumpAndSettle();
    }

    await expectPadRows();
    expect(tester.getSize(notes).height, greaterThanOrEqualTo(48));
    expect(find.text('Notes · 10').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Notes · 10'));
    await tester.pumpAndSettle();
    expect(tester.getSize(notes).height, greaterThanOrEqualTo(48));
    await expectPadRows();
    final scrollable = find.descendant(
      of: notes,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
  });
}
