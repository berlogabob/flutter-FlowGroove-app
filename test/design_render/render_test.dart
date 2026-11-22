import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/routed_test_harness.dart';
import 'fixtures.dart';
import 'fonts.dart';
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
      await pumpRoutedTestApp(
        tester,
        initialLocation: fillRoute(spec['route'] as String),
        overrides: renderOverrides(),
        themeMode: mode == 'light' ? ThemeMode.light : ThemeMode.dark,
        productionRoutes: true,
      );
      await pumpRender(tester, key);
      final output = Platform.environment['RENDER_OUT'];
      if (output != null) {
        final directory = Directory(output)..createSync(recursive: true);
        File('${directory.path}/$key@$mode-412-1.00.json')
            .writeAsStringSync(jsonEncode(dumpTree(tester)));
      }
    });
  }
}
