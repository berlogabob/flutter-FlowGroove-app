import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/app_filter_chip.dart';
import 'package:flowgroove/widgets/custom_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

  testWidgets('plain Dialog counts as a dialog kind', (tester) async {
    await pump(tester, const Dialog(child: Text('D')));
    expect(values(dumpTree(tester), 'kinds', 'kind'), ['dialog']);
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
  testWidgets('omits transparent, invisible and clipped text', (tester) async {
    await pump(
      tester,
      const Column(
        children: [
          Opacity(opacity: 0, child: Text('transparent')),
          Visibility(
            visible: false,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: Text('invisible'),
          ),
          ClipRect(
            child: SizedBox(
              width: 100,
              height: 20,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxHeight: 100,
                child: Column(
                  children: [SizedBox(height: 50), Text('clipped')],
                ),
              ),
            ),
          ),
          Text('visible'),
        ],
      ),
    );
    expect(values(dumpTree(tester), 'texts', 'v'), ['visible']);
  });

  testWidgets('retains scrollable text below the viewport as offscreen', (
    tester,
  ) async {
    await pump(
      tester,
      const Column(children: [SizedBox(height: 900), Text('below')]),
    );
    final texts = dumpTree(tester)['texts'] as List;
    expect(texts.single['v'], 'below');
    expect(texts.single['offscreen'], true);
  });

  testWidgets('rounds geometry to half pixels and sorts by y, x, then text', (
    tester,
  ) async {
    await pump(
      tester,
      const SizedBox(
        height: 100,
        child: Stack(
          children: [
            Positioned(left: 1.24, top: 2.26, child: Text('Z')),
            Positioned(left: 1.24, top: 2.26, child: Text('A')),
            Positioned(left: 0, top: 3, child: Text('later')),
          ],
        ),
      ),
    );
    final texts = dumpTree(tester)['texts'] as List;
    expect(texts.map((e) => e['v']).toList(), ['A', 'Z', 'later']);
    expect(texts.first['x'], 1.0);
    expect(texts.first['y'], 2.5);
    for (final item in texts) {
      for (final field in ['x', 'y', 'w', 'h']) {
        expect((item[field] as num) * 2, ((item[field] as num) * 2).round());
      }
    }
  });
}
