import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'png.dart';

void main() {
  testWidgets('writes painted pixels at the view device pixel ratio', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('png_test_');
    addTearDown(() => directory.deleteSync(recursive: true));
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(30, 30);
    addTearDown(tester.view.reset);
    const key = Key('png');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: ColoredBox(color: Color(0xffff0000)),
      ),
    );
    final path = '${directory.path}/image.png';
    await writePng(tester, key, path);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        File(path).readAsBytesSync(),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 30);
      expect(frame.image.height, 30);
      final pixels = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(pixels!.buffer.asUint8List().sublist(0, 4), [255, 0, 0, 255]);
      frame.image.dispose();
      codec.dispose();
    });
  });
}
