import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

Future<List<String>> loadAppFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  final families = <String>[];
  for (final entry in manifest) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
    families.add(family);
  }
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File((await Process.run('which', ['flutter'])).stdout.toString().trim())
          .resolveSymbolicLinksSync()
          .replaceFirst(RegExp(r'/bin/flutter$'), '');
  for (final family in ['Arial', 'Roboto']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(
        File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
        ).readAsBytes().then((bytes) => bytes.buffer.asByteData()),
      );
    }
    await loader.load();
    families.add(family);
  }
  return families;
}
