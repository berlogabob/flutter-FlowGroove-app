import 'dart:math';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/take_splitter.dart';
import 'package:flutter_test/flutter_test.dart';

Int16List _rehearsal(List<int> seconds) {
  const rate = 2000;
  final random = Random(42);
  return Int16List.fromList([
    for (var block = 0; block < seconds.length; block++)
      for (var i = 0; i < seconds[block] * rate; i++)
        if (block.isOdd) 0 else random.nextInt(20001) - 10000,
  ]);
}

void main() {
  test('three songs give two cuts in the middle of quiet gaps', () {
    expect(suggestTakeCuts(_rehearsal([80, 6, 80, 6, 80]), 2000), [
      83000,
      169000,
    ]);
  });

  test('a gap shorter than four seconds is ignored', () {
    expect(suggestTakeCuts(_rehearsal([80, 3, 80]), 2000), isEmpty);
  });

  test('a too-short first take is merged into the next song', () {
    expect(suggestTakeCuts(_rehearsal([20, 6, 80, 6, 80]), 2000), [109000]);
  });

  test('a too-short last take is merged into the previous song', () {
    expect(suggestTakeCuts(_rehearsal([80, 6, 80, 6, 20]), 2000), [83000]);
  });

  test('empty PCM, invalid rates and all silence give no cuts', () {
    expect(suggestTakeCuts(Int16List(0), 2000), isEmpty);
    expect(suggestTakeCuts(Int16List(100), 0), isEmpty);
    expect(suggestTakeCuts(Int16List(300000), 2000), isEmpty);
  });
}
