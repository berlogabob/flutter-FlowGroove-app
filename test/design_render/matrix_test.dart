import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'matrix.dart';

void main() {
  test('names and enumerates matrix cells', () {
    expect(cellName('home', 'dark', 412, 1), 'home@dark-412-1.00');
    expect(allCells('a').length, 16);
  });

  test('classifies a real error as a failure', () {
    final result = classifyCellErrors([
      FlutterErrorDetails(exception: StateError('broken')),
    ]);
    expect(result.failures, hasLength(1));
    expect(result.failures.single, contains('broken'));
    expect(result.overflows, isEmpty);
  });

  testWidgets('classifies a real render overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [SizedBox(width: 500)]),
        ),
      );
    } finally {
      FlutterError.onError = previous;
    }
    final result = classifyCellErrors(errors);
    expect(result.overflows, hasLength(1));
    expect(result.overflows.single['kind'], 'overflow');
    expect(result.overflows.single['widget'], isNotEmpty);
    expect(result.overflows.single['px'], greaterThan(0));
    expect(result.failures, isEmpty);
  });
}
