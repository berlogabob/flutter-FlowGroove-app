import 'package:flutter_test/flutter_test.dart';

const kMatrixWidths = {360: 800.0, 393: 852.0, 412: 915.0, 420: 933.0};
const kTextScales = [1.0, 1.3];

String cellName(String key, String theme, double width, double scale) =>
    '$key@$theme-${width.toStringAsFixed(0)}-${scale.toStringAsFixed(2)}';

List<String> allCells(String key) => [
  for (final theme in ['light', 'dark'])
    for (final width in kMatrixWidths.keys)
      for (final scale in kTextScales)
        cellName(key, theme, width.toDouble(), scale),
];

Future<String> recordCell(
  WidgetTester tester,
  Future<void> Function() render,
) async {
  Object? error;
  try {
    await render();
  } catch (exception) {
    error = exception;
  }
  final pendingError = tester.takeException();
  error ??= pendingError;
  if (error == null) return 'ok';
  final message = error.toString();
  if (message.contains('overflowed')) return 'overflow';
  return 'error: ${message.split('\n').first}';
}
