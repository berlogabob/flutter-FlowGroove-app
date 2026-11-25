// flutter drive host side of integration_test/check: writes the results the
// suite reported to build/check/<platform>.json.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final platform = data?['platform'] ?? 'unknown';
    final file = File('build/check/$platform.json')
      ..createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data?['results'] ?? [])}\n',
    );
  },
);
