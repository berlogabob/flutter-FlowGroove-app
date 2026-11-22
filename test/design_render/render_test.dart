import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/routed_test_harness.dart';
import 'fixtures.dart';
import 'fonts.dart';
import 'matrix.dart';
import 'png.dart';
import 'tree_dump.dart';

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
  final output = Platform.environment['RENDER_OUT'];
  final matrixFile = output == null ? null : File('$output/matrix.json');
  final results = <String, dynamic>{};

  setUpAll(() async {
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

  testWidgets('writes a PNG at logical pixel dimensions', (tester) async {
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
    expect(header.getUint32(16), 412);
    expect(header.getUint32(20), 915);
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
                kMatrixWidths[width.toInt()]! * 3,
              );
            addTearDown(tester.view.reset);
            const boundaryKey = Key('render-boundary');
            Future<void> render() async {
              await pumpRoutedTestApp(
                tester,
                initialLocation: fillRoute(spec['route'] as String),
                overrides: renderOverrides(),
                themeMode: theme == 'light' ? ThemeMode.light : ThemeMode.dark,
                textScale: scale,
                productionRoutes: true,
                boundaryKey: boundaryKey,
              );
              await pumpRender(tester, key);
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
              await render();
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
            expect(find.text('Page Not Found'), findsNothing);
          });
        }
      }
    }
  }
}
