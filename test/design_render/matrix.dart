import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

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

({List<Map<String, Object>> overflows, List<String> failures})
classifyCellErrors(List<FlutterErrorDetails> errors) {
  final overflows = <Map<String, Object>>[];
  final failures = <String>[];
  for (final details in errors) {
    final summary = details.summary.toString();
    if (details.exception is FlutterError && summary.contains('overflowed')) {
      final pixels = RegExp('overflowed by ([0-9.eE+-]+) pixels')
          .firstMatch(summary);
      final creators = details.informationCollector
          ?.call()
          .whereType<DiagnosticsDebugCreator>();
      overflows.add({
        'kind': 'overflow',
        'widget':
            creators?.firstOrNull?.value.toString().split('\n').first ?? '',
        'px': pixels == null ? 0 : double.parse(pixels.group(1)!),
      });
    } else {
      failures.add(details.exceptionAsString());
    }
  }
  return (overflows: overflows, failures: failures);
}
