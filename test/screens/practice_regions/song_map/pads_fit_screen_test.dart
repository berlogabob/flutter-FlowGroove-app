import 'package:flowgroove/models/audio_region.dart';
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
        find.descendant(of: banner, matching: find.text('123.5 BPM')),
        findsOneWidget,
      );
      expect(find.text('Stretch to 124').hitTestable(), findsOneWidget);
      expect(find.text('Keep').hitTestable(), findsOneWidget);

      final screen =
          Offset.zero &
          (tester.view.physicalSize / tester.view.devicePixelRatio);
      final transport = tester.getRect(find.byType(SongMapTransport));
      final rows = <double>[];
      for (final (index, region) in regions.indexed) {
        final pad = find.byKey(ValueKey('region-pad-${region.id}'));
        final rect = tester.getRect(pad);
        expect(rect.left, greaterThanOrEqualTo(screen.left));
        expect(rect.right, lessThanOrEqualTo(screen.right));
        expect(rect.top, greaterThanOrEqualTo(screen.top));
        expect(rect.bottom, lessThanOrEqualTo(transport.top));
        expect(rect.height, 64);
        rows.add(rect.top);
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
      expect(rows.take(4), everyElement(rows.first));
      expect(rows.skip(4), everyElement(rows.last));
      expect(rows.last, greaterThan(rows.first));
      expect(find.text('Unnamed'), findsNothing);
      expect(find.textContaining('No notes yet'), findsNothing);
      expect(find.text('at 0:00').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('Notes gives way to two pad rows on a short, narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(350, 570);
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
    final rects = pads.map(tester.getRect).toList();
    expect(rects.take(3).map((r) => r.top), everyElement(rects.first.top));
    expect(rects.skip(3).map((r) => r.top), everyElement(rects.last.top));
    expect(rects.last.top, greaterThan(rects.first.top));
    for (final pad in pads) {
      expect(pad.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(pad).bottom,
        lessThanOrEqualTo(tester.getRect(notes).top),
      );
    }
    expect(tester.getSize(notes).height, greaterThanOrEqualTo(48));
    expect(find.text('Notes · 10').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Notes · 10'));
    await tester.pumpAndSettle();
    expect(tester.getSize(notes).height, greaterThanOrEqualTo(48));
    for (final pad in pads) {
      expect(
        tester.getRect(pad).bottom,
        lessThanOrEqualTo(tester.getRect(notes).top),
      );
    }
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
