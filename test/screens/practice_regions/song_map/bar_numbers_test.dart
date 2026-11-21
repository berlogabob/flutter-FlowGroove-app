import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

const _duration = Duration(seconds: 166);
const _barMs = 60000 / 170 * 4;
const _approvedDownbeatMs = 1058.8235294117632;

// Section boundaries from scripts/audio_structure/keys/inocente-approved.txt.
const _sections = [
  ('Intro 1', 0.0, 8),
  ('Part B 1', 12.352941, 8),
  ('Chorus 1', 23.647059, 12),
  ('Part D 1', 40.588235, 16),
  ('Part E 1', 63.176471, 8),
  ('Chorus 2', 74.470588, 12),
  ('Part D 2', 91.411765, 16),
  ('Bridge 1', 114.0, 12),
  ('Bridge 2', 130.941176, 4),
  ('Part D 3', 136.588235, 21),
];

List<AudioRegion> _regions() => [
  for (final (index, (name, start, _)) in _sections.indexed)
    // Give Chorus 1 three parts to exercise its pad labels.
    for (var part = 0; part < (index == 2 ? 3 : 1); part++)
      AudioRegion(
        id: '$index-$part',
        name: '$name ${String.fromCharCode(97 + part)}',
        section: name,
        startMs: (start * 1000 + part * 4 * _barMs).round(),
        endMs: index == 2 && part < 2
            ? (start * 1000 + (part + 1) * 4 * _barMs).round()
            : index + 1 < _sections.length
            ? (_sections[index + 1].$2 * 1000).round()
            : _duration.inMilliseconds,
      ),
];

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  final fixture = PracticeRegionsScreenFixture(duration: _duration);

  setUp(() {
    final decodePcm = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm = (
      _, {
      required sampleRate,
      required durationMs,
    }) async => null;
    addTearDown(() => PracticeRegionsScreen.decodePcm = decodePcm);
  });

  for (final (phone, size) in const [
    ('P30', Size(1080, 2340)),
    ('A24', Size(1260, 2800)),
  ]) {
    for (final offsetMs in [2471, 1059, 1059 - 6]) {
      testWidgets('$phone shows Inocente bar numbers with offset $offsetMs', (
        tester,
      ) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final entry = PracticeRegionsScreenFixture.entry(
          songId: 'song-a',
          grid: AudioGrid(bpm: 170, offsetMs: offsetMs),
          regions: _regions(),
        ).copyWith(peaks: const [20, 60, 40]);
        await fixture.pump(tester, entry);

        final transport = find.byType(SongMapTransport);
        for (final (index, (name, _, bars)) in _sections.indexed) {
          final pad = _key('region-pad-$index-0');
          final subtitle = find.descendant(
            of: pad,
            matching: find.text('$bars bars'),
          );
          expect(subtitle, findsOneWidget, reason: name);
          await tester.ensureVisible(pad);
          await tester.pumpAndSettle();
          expect(subtitle.hitTestable(), findsOneWidget, reason: name);
          final rect = tester.getRect(pad);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width / 3));
          expect(
            rect.bottom,
            lessThanOrEqualTo(tester.getTopLeft(transport).dy),
          );
        }

        Future<void> tap(Finder finder) async {
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<void> openSection(int index) async {
          final pad = _key('region-pad-$index-0');
          await tester.ensureVisible(pad);
          await tester.pumpAndSettle();
          await tap(_key('song-map-key-Shift'));
          await tap(pad);
        }

        await openSection(0);
        final ruler = _key('song-map-ruler');
        final labels = find.descendant(of: ruler, matching: find.byType(Text));
        expect(tester.widgetList<Text>(labels).map((label) => label.data), [
          for (var bar = 1; bar <= 8; bar++) '$bar',
        ]);
        final rulerRect = tester.getRect(ruler);
        final waveform = tester.getRect(_key('song-map-zoom-waveform'));
        expect(rulerRect.left, waveform.left);
        expect(rulerRect.width, waveform.width);
        final introEndMs = (_sections[1].$2 * 1000).round();
        const physicalPixel = 1 / 3;
        // Use the saved phase for the deliberately early grid. For the other
        // two offsets the approved downbeat gives the same line within 1 px.
        final firstDownbeatMs = offsetMs == 1059 - 6
            ? offsetMs.toDouble()
            : _approvedDownbeatMs;
        double x(double ms) => waveform.left + ms / introEndMs * waveform.width;
        Finder ticks(Finder row) =>
            find.descendant(of: row, matching: find.byType(ColoredBox));

        final barTicks = ticks(ruler);
        expect(barTicks, findsNWidgets(8));
        for (var bar = 0; bar < 8; bar++) {
          final tick = tester.getRect(barTicks.at(bar));
          expect(
            tick.left,
            closeTo(x(firstDownbeatMs + bar * _barMs), physicalPixel),
          );
          expect(
            tester.getTopLeft(labels.at(bar)).dx,
            greaterThanOrEqualTo(tick.right),
          );
        }

        final introPart = _key('song-map-part-0-0');
        expect(
          find.descendant(of: introPart, matching: find.text('8 bars')),
          findsOneWidget,
        );
        await tester.tap(introPart);
        await tester.pump(const Duration(milliseconds: 60));
        await tap(introPart);
        final beatRuler = _key('song-map-beats');
        expect(tester.getRect(beatRuler).left, rulerRect.left);
        final beatTicks = ticks(beatRuler);
        expect(beatTicks, findsNWidgets(32));
        for (var beat = 0; beat < 32; beat++) {
          expect(
            tester.getTopLeft(beatTicks.at(beat)).dx,
            closeTo(x(firstDownbeatMs + beat * _barMs / 4), physicalPixel),
          );
        }
        final firstBeatLabel = find
            .descendant(of: beatRuler, matching: find.byType(Text))
            .first;
        expect(tester.widget<Text>(firstBeatLabel).data, '1');
        expect(
          tester.getTopLeft(firstBeatLabel).dx,
          greaterThanOrEqualTo(tester.getTopRight(beatTicks.first).dx),
        );

        await tap(_key('song-map-key-‹ Song'));
        await openSection(2);
        for (final (part, label) in [
          'Bars 17-20',
          'Bars 21-24',
          'Bars 25-28',
        ].indexed) {
          expect(
            find
                .descendant(
                  of: _key('region-pad-2-$part'),
                  matching: find.text(label),
                )
                .hitTestable(),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
