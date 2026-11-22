import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads app font families', () async {
    expect(
      await loadAppFonts(),
      containsAll(['Marcellus', 'Source Serif 4', 'MaterialIcons']),
    );
  });
}
