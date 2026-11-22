import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'matrix.dart';

void main() {
  test('names and enumerates matrix cells', () {
    expect(cellName('home', 'dark', 412, 1.0), 'home@dark-412-1.00');
    expect(allCells('a').length, 16);
  });

  testWidgets('records a render overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final result = await recordCell(tester, () async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [SizedBox(width: 500)]),
        ),
      );
    });
    expect(result, 'overflow');
  });
}
