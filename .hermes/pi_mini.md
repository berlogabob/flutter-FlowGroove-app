Create a file test/repositories/temp_integration.dart with this content:

import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/repositories/firestore_song_repository.dart';
import 'package:flowgroove/helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await TestHelpers.initializeFirebase();
  });

  test('placeholder', () {
    expect(true, isTrue);
  });
}
