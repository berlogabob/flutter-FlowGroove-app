import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads app font families', () async {
    expect(
      await loadAppFonts(),
      containsAll(['Marcellus', 'Source Serif 4', 'MaterialIcons']),
    );
  });

  test('renders control text with a proportional font', () async {
    await loadAppFonts();
    final text = TextPainter(
      text: const TextSpan(
        text: 'Continue with Google',
        style: TextStyle(fontFamily: 'Arial', fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(text.width, lessThan(0.8 * 21 * 14));
    text.dispose();
  });
}
