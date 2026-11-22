import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/app_filter_chip.dart';
import 'package:flowgroove/widgets/custom_button.dart';

import 'tree_dump.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: MonoPulseTheme.theme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  List<Object?> values(Map<String, Object?> dump, String key, String field) =>
      (dump[key] as List).map((item) => (item as Map)[field]).toList();

  testWidgets('captures text and deduplicates nested kinds', (tester) async {
    await pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A'),
          CustomButton(label: 'Go', onPressed: () {}),
          AppFilterChip(label: 'C', selected: false, onSelected: (_) {}),
        ],
      ),
    );
    final dump = dumpTree(tester);
    expect(values(dump, 'texts', 'v'), ['A', 'Go', 'C']);
    expect(values(dump, 'kinds', 'kind'), ['button', 'chip']);
  });

  testWidgets('does not capture icon glyphs as text', (tester) async {
    await pump(tester, const Row(children: [Icon(Icons.add), Text('B')]));
    expect(values(dumpTree(tester), 'texts', 'v'), ['B']);
  });

  testWidgets('excludes offstage children', (tester) async {
    await pump(
      tester,
      const IndexedStack(index: 0, children: [Text('A'), Text('B')]),
    );
    expect(values(dumpTree(tester), 'texts', 'v'), ['A']);
  });

  testWidgets('drops empty and whitespace-only text', (tester) async {
    await pump(
      tester,
      const Column(children: [Text(''), Text('  \n '), Text('A')]),
    );
    expect(values(dumpTree(tester), 'texts', 'v'), ['A']);
  });
}
