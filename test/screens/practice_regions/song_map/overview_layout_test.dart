import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/audio/waveform_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

void main() {
  final fixture = PracticeRegionsScreenFixture(
    duration: const Duration(seconds: 24),
  );
  const regions = [
    AudioRegion(id: 'intro', name: 'Intro', startMs: 0, endMs: 4000),
    AudioRegion(
      id: 'chorus-a',
      name: 'Chorus a',
      section: 'Chorus',
      startMs: 4000,
      endMs: 8000,
    ),
    AudioRegion(
      id: 'chorus-b',
      name: 'Chorus b',
      section: 'Chorus',
      startMs: 8000,
      endMs: 14000,
    ),
    AudioRegion(id: 'end', name: 'End', startMs: 14000, endMs: 24000),
  ];
  final entry = PracticeRegionsScreenFixture.entry(
    regions: regions,
    grid: const AudioGrid(bpm: 120),
  ).copyWith(peaks: const [20, 60, 40], peaksRms: true);

  for (final theme in [MonoPulseTheme.lightTheme, MonoPulseTheme.theme]) {
    testWidgets('overview and zoom align on a ${theme.brightness.name} phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final decode = PracticeRegionsScreen.decodePcm;
      PracticeRegionsScreen.decodePcm = (
        _, {
        required sampleRate,
        required durationMs,
      }) async => null;
      addTearDown(() => PracticeRegionsScreen.decodePcm = decode);
      await fixture.pump(tester, entry, theme: theme);

      Finder key(String name) => find.byKey(ValueKey(name));
      final overview = key('song-map-overview');
      final zoom = key('song-map-zoom');
      final wholeWave = key('song-map-overview-waveform');
      final zoomWave = key('song-map-zoom-waveform');
      final chorus = key('song-map-section-chorus-a');
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final pixel = 1 / tester.view.devicePixelRatio;
      final waveform = tester.getRect(wholeWave);
      expect(overview, findsOneWidget);
      expect(zoom, findsOneWidget);
      expect(tester.getSize(overview).width, closeTo(screenWidth - 16, 1e-9));
      expect(waveform.left, closeTo(8, 1e-9));
      expect(waveform.width, closeTo(screenWidth - 16, 1e-9));
      expect(tester.widget<SongMapOverview>(overview).viewport, (
        startMs: 0,
        endMs: 24000,
      ));
      expect(tester.widget<SongMapTimeline>(zoom).viewport, (
        startMs: 0,
        endMs: 4000,
      ));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter != null &&
              (w.painter is WaveformPainter ||
                  w.key == const ValueKey('song-map-zoom-waveform')),
        ),
        findsNWidgets(2),
      );
      expect(
        tester.widget<CustomPaint>(wholeWave).painter,
        isA<WaveformPainter>(),
      );
      expect(
        tester.widget<CustomPaint>(zoomWave).painter,
        isNot(isA<WaveformPainter>()),
      );
      double x(int ms) => waveform.left + waveform.width * ms / 24000;
      for (final (id, start, end) in [
        ('intro', 0, 4000),
        ('chorus-a', 4000, 14000),
        ('end', 14000, 24000),
      ]) {
        final block = tester.getRect(key('song-map-section-$id'));
        final band = tester.getRect(
          find.descendant(of: overview, matching: key('song-map-band-$id')),
        );
        expect(block.left, closeTo(x(start), pixel));
        expect(block.right, closeTo(x(end), pixel));
        expect(block.left, closeTo(band.left, pixel));
        expect(block.right, closeTo(band.right, pixel));
        expect(block.top, closeTo(waveform.bottom, pixel));
      }

      await tester.tap(chorus);
      await tester.pump(const Duration(milliseconds: 350));
      await fixture.settleAudio(tester);
      expect(tester.getRect(wholeWave), waveform);
      expect(find.textContaining('Looping'), findsNothing);
      expect(tester.widget<SongMapTimeline>(zoom).viewport, (
        startMs: 4000,
        endMs: 14000,
      ));
      Border outline() =>
          (tester.widget<Container>(chorus).decoration! as BoxDecoration)
                  .border!
              as Border;
      expect(outline().top.width, 3);
      expect(outline().top.color, tester.element(chorus).mp.textPrimary);

      await tester.tapAt(Offset(x(9000), waveform.center.dy));
      await fixture.settleAudio(tester);
      await tester.tap(find.text('Play'));
      await fixture.settleAudio(tester);
      expect(outline().top.width, 3);
      expect(outline().top.color, MonoPulseColors.accentOrange);
      await tester.tap(find.text('Pause'));
      await fixture.settleAudio(tester);

      final zoomRect = tester.getRect(zoomWave);
      final partA = tester.getRect(key('song-map-part-chorus-a'));
      final partB = tester.getRect(key('song-map-part-chorus-b'));
      expect(partA.left, closeTo(zoomRect.left, pixel));
      expect(partA.right, closeTo(zoomRect.left + zoomRect.width * .4, pixel));
      expect(partB.left, closeTo(partA.right, pixel));
      expect(partB.right, closeTo(zoomRect.right, pixel));
      final ruler = key('song-map-ruler');
      expect(tester.getRect(ruler).top, greaterThanOrEqualTo(partA.bottom));
      final bars = tester.widgetList<Text>(
        find.descendant(of: ruler, matching: find.byType(Text)),
      );
      expect(bars.map((bar) => bar.data), ['3', '4', '5', '6', '7']);

      // The overview is the only whole-song letter strip, even inside a section.
      await tester.tap(chorus);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(chorus);
      await tester.pumpAndSettle();
      expect(tester.widget<SongMapTimeline>(zoom).view.sectionIndex, 1);
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'SongMapMinimap',
        ),
        findsNothing,
      );
      expect(key('song-map-sections'), findsOneWidget);
      expect(tester.getRect(wholeWave), waveform);
      expect(tester.takeException(), isNull);
    });
  }
}
