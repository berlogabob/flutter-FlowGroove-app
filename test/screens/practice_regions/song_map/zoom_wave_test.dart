import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/services/audio/audio_file_cache.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

void main() {
  const rate = 22050;
  const duration = Duration(seconds: 16);
  final fixture = PracticeRegionsScreenFixture(duration: duration);
  final entry = PracticeRegionsScreenFixture.entry(
    grid: const AudioGrid(bpm: 120),
    regions: const [
      AudioRegion(id: 'intro', name: 'Intro', startMs: 0, endMs: 12000),
      AudioRegion(id: 'bridge', name: 'Bridge 2', startMs: 12000, endMs: 16000),
    ],
  );
  final zoom = find.byKey(const ValueKey('song-map-zoom'));
  final waveform = find.byKey(const ValueKey('song-map-zoom-waveform'));
  final pads = find.byType(SongMapPads);
  Finder pad(String id) => find.byKey(ValueKey('region-pad-$id'));

  List<({double left, double right, double height})> bars(WidgetTester tester) {
    final canvas = TestRecordingCanvas();
    tester
        .widget<CustomPaint>(waveform)
        .painter!
        .paint(canvas, tester.getSize(waveform));
    return [
      for (final call in canvas.invocations)
        if (call.invocation.memberName == #drawLine)
          (
            left:
                (call.invocation.positionalArguments[0] as Offset).dx -
                (call.invocation.positionalArguments[2] as Paint).strokeWidth /
                    2,
            right:
                (call.invocation.positionalArguments[0] as Offset).dx +
                (call.invocation.positionalArguments[2] as Paint).strokeWidth /
                    2,
            height:
                (call.invocation.positionalArguments[1] as Offset).dy -
                (call.invocation.positionalArguments[0] as Offset).dy,
          ),
    ];
  }

  setUp(() {
    final original = PracticeRegionsScreen.decodePcm;
    addTearDown(() => PracticeRegionsScreen.decodePcm = original);
  });

  for (final (phone, size) in [
    ('P30', const Size(1080, 2340)),
    ('A24', const Size(1260, 2800)),
  ]) {
    void setPhone(WidgetTester tester) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 3
        ..padding = const FakeViewPadding(top: 72, bottom: 72);
      addTearDown(tester.view.reset);
    }

    testWidgets('$phone loads a saved zoom once without moving the layout', (
      tester,
    ) async {
      setPhone(tester);
      final decoded = Completer<Int16List?>();
      final requests = <(int, int)>[];
      PracticeRegionsScreen.decodePcm =
          (_, {required sampleRate, required durationMs}) {
            requests.add((sampleRate, durationMs));
            return decoded.future;
          };

      await fixture.pump(tester, entry, theme: MonoPulseTheme.theme);
      expect(requests, [(rate, duration.inMilliseconds)]);
      await tester.tap(pad('bridge'));
      await fixture.settleAudio(tester);
      expect(tester.widget<SongMapTimeline>(zoom).viewport, (
        startMs: 12000,
        endMs: 16000,
      ));
      expect(tester.widget<SongMapTimeline>(zoom).pcm, isNull);
      final targets = [zoom, waveform, pads, pad('intro'), pad('bridge')];
      final before = targets.map(tester.getRect).toList();

      final pcm = Int16List(rate * duration.inSeconds)
        ..fillRange(12 * rate, 16 * rate, 12000);
      decoded.complete(pcm);
      await tester.pumpAndSettle();
      expect(tester.widget<SongMapTimeline>(zoom).pcm, same(pcm));
      final strokes = bars(tester);
      expect(strokes, hasLength((before[1].width / 3).ceil()));
      expect(
        strokes.map((bar) => bar.height),
        everyElement(greaterThan(before[1].height * 0.9)),
      );
      expect(targets.map(tester.getRect), before);

      await tester.tap(pad('intro'));
      await fixture.settleAudio(tester);
      expect(tester.widget<SongMapTimeline>(zoom).pcm, same(pcm));
      expect(requests, [(rate, duration.inMilliseconds)]);
    });

    testWidgets(
      '$phone fills the zoom with interpolated bars on decode failure',
      (tester) async {
        setPhone(tester);
        audioFileCache = (_, _) async => throw StateError('cache unavailable');
        var decodes = 0;
        PracticeRegionsScreen.decodePcm =
            (_, {required sampleRate, required durationMs}) async {
              decodes++;
              return null;
            };

        await fixture.pump(
          tester,
          entry.copyWith(
            peaks: List.generate(20, (i) => i.isEven ? 24 : 96),
            peaksRms: true,
          ),
          theme: MonoPulseTheme.theme,
        );
        await tester.tap(pad('bridge'));
        await fixture.settleAudio(tester);
        expect(decodes, 1);
        expect(tester.widget<SongMapTimeline>(zoom).pcm, isNull);

        final strokes = bars(tester);
        final width = tester.getSize(waveform).width;
        final onePixel = 1 / tester.view.devicePixelRatio;
        expect(strokes, hasLength(width.ceil()));
        expect(strokes.first.left, lessThanOrEqualTo(onePixel));
        expect(width - strokes.last.right, lessThanOrEqualTo(onePixel));
        expect(strokes.map((bar) => bar.height).toSet().length, greaterThan(2));
        for (var i = 1; i < strokes.length; i++) {
          expect(
            strokes[i].left - strokes[i - 1].right,
            lessThanOrEqualTo(onePixel),
          );
        }
      },
    );
  }
}
