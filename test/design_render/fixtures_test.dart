import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test('fills path and query placeholders', () {
    expect(
      fillRoute('/main/bands/{band}/rehearsals/{rehearsal}'),
      '/main/bands/band1/rehearsals/reh1',
    );
    expect(
      fillRoute('/join-welcome?code={invite}'),
      '/join-welcome?code=INVITE1',
    );
  });

  test('reports unknown placeholders', () {
    expect(
      () => fillRoute('/x/{nope}'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('no fixture for {nope}'),
        ),
      ),
    );
  });

  test('provides render overrides', () {
    expect(renderOverrides(), isNotEmpty);
  });
}
