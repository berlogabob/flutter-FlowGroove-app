import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

void main() {
  const duration = Duration(seconds: 48);
  final fixture = PracticeRegionsScreenFixture(duration: duration);
  final screen = find.byType(PracticeRegionsScreen);
  final overview = find.byKey(const ValueKey('song-map-overview'));
  final zoom = find.byKey(const ValueKey('song-map-zoom'));
  final review = find.textContaining(RegExp(r'\d+ found$'));
  final dialog = find.widgetWithText(AlertDialog, 'Save the new section map?');

  setUp(() {
    final decodePcm = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm =
        (_, {required sampleRate, required durationMs}) async {
          final pcm = Int16List(sampleRate * duration.inSeconds);
          for (var i = 0; i < pcm.length; i++) {
            final frequency = (i ~/ (sampleRate * 16)).isEven ? 110 : 1760;
            pcm[i] = (4000 * math.sin(2 * math.pi * frequency * i / sampleRate))
                .round();
          }
          return pcm;
        };
    addTearDown(() => PracticeRegionsScreen.decodePcm = decodePcm);
  });

  Finder action(String label) =>
      find.descendant(of: dialog, matching: find.text(label)).hitTestable();

  Future<void> analyze(WidgetTester tester, {required ThemeData theme}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = PracticeRegionsScreenFixture.entry(regions: const [])
        .copyWith(title: 'Inocente', peaks: const [20, 60, 40]);
    await fixture.pump(tester, entry, theme: theme, pushRoute: true);
    await tester.tap(find.text('Analyze song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze'));
    for (var i = 0; i < 20 && review.evaluate().isEmpty; i++) {
      await fixture.settleAudio(tester);
    }

    expect(review.hitTestable(), findsOneWidget);
    expect(find.textContaining('Sections'), findsOneWidget);
    expect(find.text('Done').hitTestable(), findsOneWidget);
    expect(find.text('Discard').hitTestable(), findsOneWidget);
    expect(fixture.savedEntries, isEmpty);
    expect(
      tester.getRect(overview).bottom,
      lessThanOrEqualTo(tester.getRect(zoom).top),
    );
    expect(
      tester.getRect(zoom).bottom,
      lessThanOrEqualTo(tester.getRect(review).top),
    );
    expect(
      tester.getRect(review).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(SongMapTransport)).top),
    );
  }

  void expectDashedBlock(WidgetTester tester, Key key) {
    final block = find.byKey(key);
    expect(block.hitTestable(), findsOneWidget);
    final decoration =
        tester.widget<Container>(block).decoration! as BoxDecoration;
    final canvas = TestRecordingCanvas();
    final rect = Offset.zero & tester.getSize(block);
    decoration.border!.paint(canvas, rect);
    final lengths = [
      for (final call in canvas.invocations)
        if (call.invocation.memberName == #drawPath)
          (call.invocation.positionalArguments.first as Path)
              .computeMetrics()
              .single
              .length,
    ];
    expect(lengths.length, greaterThan(1));
    expect(
      lengths,
      everyElement(lessThanOrEqualTo(MonoPulseSpacing.xs + 0.01)),
    );
    final perimeter =
        2 *
        (rect.width + rect.height - decoration.border!.dimensions.horizontal);
    expect(lengths.reduce((a, b) => a + b), lessThan(perimeter));
  }

  testWidgets(
    'app bar back offers Save and persists the preview before leaving',
    (tester) async {
      await analyze(tester, theme: MonoPulseTheme.theme);
      final view = tester.widget<SongMapTimeline>(overview).view;
      final candidate = view.regions;
      expect(candidate, isNotEmpty);
      expectDashedBlock(
        tester,
        ValueKey('song-map-section-${view.sections.first.id}'),
      );
      expectDashedBlock(
        tester,
        ValueKey('song-map-part-${view.sectionParts(0).first.id}'),
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(fixture.savedEntries, isEmpty);
      await tester.tap(action('Save'));
      await fixture.settleAudio(tester);
      await tester.pumpAndSettle();

      expect(screen, findsNothing);
      expect(fixture.savedEntries.single.regions, candidate);
    },
  );

  testWidgets('system back offers Discard and leaves without saving', (
    tester,
  ) async {
    await analyze(tester, theme: MonoPulseTheme.lightTheme);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    await tester.tap(action('Discard'));
    await tester.pumpAndSettle();

    expect(screen, findsNothing);
    expect(fixture.savedEntries, isEmpty);
  });

  testWidgets('Cancel stays on the candidate review without saving', (
    tester,
  ) async {
    await analyze(tester, theme: MonoPulseTheme.theme);
    final map = tester.widget<SongMapTimeline>(overview).view.regions;
    await Navigator.of(tester.element(screen)).maybePop();
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    await tester.tap(action('Cancel'));
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(screen, findsOneWidget);
    expect(review.hitTestable(), findsOneWidget);
    expect(find.text('Done').hitTestable(), findsOneWidget);
    expect(tester.widget<SongMapTimeline>(overview).view.regions, map);
    expect(fixture.savedEntries, isEmpty);
  });
}
