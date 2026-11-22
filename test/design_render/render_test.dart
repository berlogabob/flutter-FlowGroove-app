import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/routed_test_harness.dart';
import 'fixtures.dart';
import 'fonts.dart';
import 'png.dart';
import 'tree_dump.dart';

const kNoSettle = {'never-settling'};

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
  setUpAll(() async {
    await loadAppFonts();
  });

  testWidgets('renders a never-settling screen within 10 s', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CircularProgressIndicator())),
    );
    await pumpRender(tester, 'never-settling');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

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
  for (final key in keys) {
    testWidgets(key, (tester) async {
      final spec = jsonDecode(
        File('design/figcraft/specs/$key.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final mode = spec['mode'] as String? ?? 'dark';
      tester.view
        ..devicePixelRatio = 3
        ..physicalSize = const Size(412 * 3, 915 * 3);
      addTearDown(tester.view.reset);
      const boundaryKey = Key('render-boundary');
      await pumpRoutedTestApp(
        tester,
        initialLocation: fillRoute(spec['route'] as String),
        overrides: renderOverrides(),
        themeMode: mode == 'light' ? ThemeMode.light : ThemeMode.dark,
        productionRoutes: true,
        boundaryKey: boundaryKey,
      );
      await pumpRender(tester, key);
      final output = Platform.environment['RENDER_OUT'];
      if (output != null) {
        final directory = Directory(output)..createSync(recursive: true);
        File('${directory.path}/$key@$mode-412-1.00.json')
            .writeAsStringSync(jsonEncode(dumpTree(tester)));
        if (Platform.environment['RENDER_PNG'] == '1') {
          await writePng(
            tester,
            boundaryKey,
            '${directory.path}/$key@$mode-412-1.00.png',
          );
        }
      }
    });
  }
}
