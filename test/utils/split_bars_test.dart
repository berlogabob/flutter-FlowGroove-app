import 'package:flowgroove/utils/split_bars.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitBars', () {
    test('splits bars evenly between parts', () {
      expect(splitBars(8, 4), [2, 2, 2, 2]);
    });

    test('assigns a single remaining bar to the first part', () {
      expect(splitBars(9, 4), [3, 2, 2, 2]);
    });

    test('assigns remaining bars to the first parts', () {
      expect(splitBars(10, 4), [3, 3, 2, 2]);
    });

    test('leaves later parts empty when there are fewer bars than parts', () {
      expect(splitBars(2, 4), [1, 1, 0, 0]);
    });

    test('returns an empty list when parts is zero', () {
      expect(splitBars(8, 0), isEmpty);
    });

    test('returns an empty list when bars is zero', () {
      expect(splitBars(0, 4), isEmpty);
    });
  });
}
