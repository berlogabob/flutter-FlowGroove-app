import 'package:flowgroove/utils/event_share_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds the canonical hash link on the web app origin', () {
    expect(
      eventShareUrl('abc.def'),
      'https://app.flowgroove.app/#/event?t=abc.def',
    );
  });

  test('encodes unsafe token characters', () {
    expect(eventShareUrl('a b&c'), contains('t=a+b%26c'));
  });
}
