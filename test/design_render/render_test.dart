import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flowgroove/widgets/practice_dashboard_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/routed_test_harness.dart';
import '../screens/practice_regions_screen_test.dart';
import 'fixtures.dart';
import 'fonts.dart';
import 'matrix.dart';
import 'openers.dart';
import 'png.dart';
import 'states.dart';
import 'tree_dump.dart';

// Frames that draw a whole scrolling screen or sheet, not one 915 px window: the
// render needs a viewport tall enough to build every row the frame lists.
const kFrameHeights = <String, double>{
  'app_settings': 3000,
  'rehearsal_detail': 3000,
  'rehearsal_edit': 3000,
  'metronome_launchpad': 3000,
  'event_kit_editor_sheet_l181': 3000,
  'event_kit_editor_sheet_l191': 3000,
  'import_lyrics_dialog': 3000,
  // The frame floats the Suggest FAB over the scrolled list; the render needs the
  // whole list above it, so the FAB lands after the last request in dump order.
  'event_share': 1100,
};

// Add screen keys and reasons here if they have perpetual animations.
const kNoSettle = <String>{};

Future<void> pumpRender(WidgetTester tester, String key) async {
  if (kNoSettle.contains(key)) {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  practiceFixture = PracticeRegionsScreenFixture(
    duration: const Duration(seconds: 204),
  );
  final output = Platform.environment['RENDER_OUT'];
  final matrixFile = output == null ? null : File('$output/matrix.json');
  final results = <String, dynamic>{};

  setUpAll(() async {
    practiceCardNow = () => DateTime(2026, 11, 24); // frames draw a Tuesday
    if (Platform.environment['RENDER_CLEAN'] == '1') {
      final directory = Directory('design/render');
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
    if (matrixFile != null && matrixFile.existsSync()) {
      results.addAll(
        jsonDecode(matrixFile.readAsStringSync()) as Map<String, dynamic>,
      );
    }
    await loadAppFonts();
  });

  tearDownAll(() {
    if (matrixFile != null && Platform.environment['RENDER_MATRIX'] == '1') {
      matrixFile.parent.createSync(recursive: true);
      matrixFile.writeAsStringSync(jsonEncode(results));
    }
  });

  testWidgets('writes a PNG at physical pixel dimensions', (tester) async {
    final directory = Directory.systemTemp.createTempSync('render_png_test_');
    addTearDown(() => directory.deleteSync(recursive: true));
    const boundaryKey = Key('png-boundary');
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(412 * 3, 915 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const RepaintBoundary(
        key: boundaryKey,
        child: SizedBox(width: 100, height: 80),
      ),
    );
    final path = '${directory.path}/image.png';
    await writePng(tester, boundaryKey, path);
    final bytes = File(path).readAsBytesSync();
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData.sublistView(bytes);
    expect(header.getUint32(16), 412 * 3);
    expect(header.getUint32(20), 915 * 3);
  });

  testWidgets('themed harness hides the debug banner', (tester) async {
    await pumpRoutedTestApp(
      tester,
      initialLocation: '/login',
      themeMode: ThemeMode.dark,
    );
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .debugShowCheckedModeBanner,
      isFalse,
    );
  });

  test('render keys are inventory spec stems', () {
    final inventory = jsonDecode(
      File('design/surfaces.json').readAsStringSync(),
    ) as List<dynamic>;
    final stems = {
      for (final surface in inventory.cast<Map<String, dynamic>>())
        if (surface['spec'] != null)
          (surface['spec'] as String).split('/').last.replaceAll('.json', ''),
    };
    final listed = File('design/render_keys.txt')
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toSet();
    expect(listed.difference(stems), isEmpty);
  });

  final keys = File('design/render_keys.txt')
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'));
  final matrix = Platform.environment['RENDER_MATRIX'] == '1';
  for (final key in keys) {
    final spec = jsonDecode(
      File('design/figcraft/specs/$key.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final route = spec['route'] as String?;
    final state = kStates[key];
    final opener = state == null ? kOpeners[key] : null;
    final mode = spec['mode'] as String? ?? 'dark';
    for (final theme in matrix ? ['light', 'dark'] : [mode]) {
      for (final width
          in matrix
              ? kMatrixWidths.keys.map((width) => width.toDouble())
              : [412.0]) {
        for (final scale in matrix ? kTextScales : [1.0]) {
          final cell = cellName(key, theme, width, scale);
          testWidgets(cell, (tester) async {
            tester.view
              ..devicePixelRatio = 3
              ..physicalSize = Size(
                width * 3,
                ((matrix ? null : kFrameHeights[key]) ??
                        kMatrixWidths[width.toInt()]!) *
                    3,
              );
            addTearDown(tester.view.reset);
            const boundaryKey = Key('render-boundary');
            Future<void> render() async {
              if (state != null) {
                stateTheme = theme == 'light'
                    ? ThemeMode.light
                    : ThemeMode.dark;
                tester.platformDispatcher.textScaleFactorTestValue = scale;
                addTearDown(
                  tester.platformDispatcher.clearTextScaleFactorTestValue,
                );
                await state(tester);
                // Every state is on the Song Map; each state asserts its own
                // level ('Sections' is the Song-level bank only, F101).
                expect(
                  find.byKey(const ValueKey('song-map-overview')),
                  findsOneWidget,
                );
              } else {
                if (route == null && opener == null) {
                  fail('no opener for $key');
                }
                final router = await pumpRoutedTestApp(
                  tester,
                  initialLocation: fillRoute(opener?.route ?? route!),
                  overrides: renderOverrides(key: key),
                  themeMode: theme == 'light'
                      ? ThemeMode.light
                      : ThemeMode.dark,
                  textScale: scale,
                  productionRoutes: true,
                  boundaryKey: boundaryKey,
                );
                await pumpRender(tester, key);
                if (opener != null) {
                  opener.open(hostContext(tester), tester, router);
                  // Show helpers that await platform or IO futures first (power
                  // family, song fetch) need real time before the modal exists.
                  for (var i = 0; opener.realAsync && i < 3; i++) {
                    await tester.runAsync(
                      () => Future<void>.delayed(
                        const Duration(milliseconds: 20),
                      ),
                    );
                    await tester.pump();
                  }
                  await pumpRender(tester, key);
                  if (opener.then != null) {
                    await opener.then!(tester);
                    await pumpRender(tester, key);
                  }
                }
              }
              final output = Platform.environment['RENDER_OUT'];
              if (output != null) {
                final directory = Directory(output)
                  ..createSync(recursive: true);
                File('${directory.path}/$cell.json')
                    .writeAsStringSync(jsonEncode(dumpTree(tester)));
                if (Platform.environment['RENDER_PNG'] == '1') {
                  await writePng(
                    tester,
                    boundaryKey,
                    '${directory.path}/$cell.png',
                  );
                }
              }
            }

            final errors = <FlutterErrorDetails>[];
            final previous = FlutterError.onError;
            FlutterError.onError = errors.add;
            try {
              await withClock(Clock.fixed(DateTime(2026, 1, 15, 10)), render);
            } finally {
              FlutterError.onError = previous;
              final classified = classifyCellErrors(errors);
              if (matrix) {
                results[cell] = classified.failures.isNotEmpty
                    ? 'error: ${classified.failures.join('\n')}'
                    : classified.overflows.isEmpty
                    ? 'ok'
                    : classified.overflows;
              }
              if (classified.failures.isNotEmpty) {
                fail(classified.failures.join('\n'));
              }
            }
            expect(find.byType(ErrorWidget), findsNothing);
            if (spec['modal'] != null) {
              // A modal spec renders a sheet or dialog over its backdrop; an opener
              // whose trigger silently did nothing would otherwise pass (F111).
              expect(
                find.byWidgetPredicate(
                  (w) =>
                      w is BottomSheet ||
                      w is Dialog ||
                      w is AlertDialog ||
                      w is SimpleDialog,
                ),
                findsWidgets,
                reason: 'modal spec $key: no sheet or dialog on screen',
              );
            }
            expect(find.text('Page Not Found'), findsNothing);
          });
        }
      }
    }
  }
}
