import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/beat_mode.dart';

void main() {
  group('BeatMode Enum', () {
    group('Enum Values', () {
      test('has three values: normal, accent, silent', () {
        expect(BeatMode.values.length, 3);
        expect(BeatMode.values, contains(BeatMode.normal));
        expect(BeatMode.values, contains(BeatMode.accent));
        expect(BeatMode.values, contains(BeatMode.silent));
      });

      test('normal is the default/first value', () {
        expect(BeatMode.normal.index, 0);
      });

      test('accent is the second value', () {
        expect(BeatMode.accent.index, 1);
      });

      test('silent is the third value', () {
        expect(BeatMode.silent.index, 2);
      });
    });

    group('BeatMode.name', () {
      test('normal has name "normal"', () {
        expect(BeatMode.normal.name, 'normal');
      });

      test('accent has name "accent"', () {
        expect(BeatMode.accent.name, 'accent');
      });

      test('silent has name "silent"', () {
        expect(BeatMode.silent.name, 'silent');
      });
    });

    group('BeatMode from string', () {
      test('parses "normal" correctly', () {
        final mode = BeatMode.values.firstWhere(
          (m) => m.name == 'normal',
          orElse: () => BeatMode.normal,
        );
        expect(mode, BeatMode.normal);
      });

      test('parses "accent" correctly', () {
        final mode = BeatMode.values.firstWhere(
          (m) => m.name == 'accent',
          orElse: () => BeatMode.normal,
        );
        expect(mode, BeatMode.accent);
      });

      test('parses "silent" correctly', () {
        final mode = BeatMode.values.firstWhere(
          (m) => m.name == 'silent',
          orElse: () => BeatMode.normal,
        );
        expect(mode, BeatMode.silent);
      });

      test('falls back to normal for unknown string', () {
        final mode = BeatMode.values.firstWhere(
          (m) => m.name == 'unknown',
          orElse: () => BeatMode.normal,
        );
        expect(mode, BeatMode.normal);
      });
    });

    group('BeatMode cycling', () {
      test('can cycle from normal to accent', () {
        final nextMode = _cycleBeatMode(BeatMode.normal);
        expect(nextMode, BeatMode.accent);
      });

      test('can cycle from accent to silent', () {
        final nextMode = _cycleBeatMode(BeatMode.accent);
        expect(nextMode, BeatMode.silent);
      });

      test('can cycle from silent to normal', () {
        final nextMode = _cycleBeatMode(BeatMode.silent);
        expect(nextMode, BeatMode.normal);
      });

      test('full cycle returns to start', () {
        var mode = BeatMode.normal;
        mode = _cycleBeatMode(mode); // accent
        mode = _cycleBeatMode(mode); // silent
        mode = _cycleBeatMode(mode); // normal
        expect(mode, BeatMode.normal);
      });
    });

    group('BeatMode semantics', () {
      test('normal mode represents default behavior', () {
        expect(BeatMode.normal.name, 'normal');
      });

      test('accent mode represents emphasized beat', () {
        expect(BeatMode.accent.name, 'accent');
      });

      test('silent mode represents muted/visual-only beat', () {
        expect(BeatMode.silent.name, 'silent');
      });
    });

    group('BeatMode in collections', () {
      test('can be used in List', () {
        final modes = [BeatMode.normal, BeatMode.accent, BeatMode.silent];
        expect(modes.length, 3);
        expect(modes[0], BeatMode.normal);
        expect(modes[1], BeatMode.accent);
        expect(modes[2], BeatMode.silent);
      });

      test('can be used in 2D List', () {
        final modes2D = [
          [BeatMode.accent, BeatMode.normal],
          [BeatMode.silent, BeatMode.normal],
        ];
        expect(modes2D.length, 2);
        expect(modes2D[0][0], BeatMode.accent);
        expect(modes2D[1][0], BeatMode.silent);
      });

      test('can be filtered', () {
        final modes = [
          BeatMode.normal,
          BeatMode.accent,
          BeatMode.silent,
          BeatMode.accent,
        ];
        final accents = modes.where((m) => m == BeatMode.accent).toList();
        expect(accents.length, 2);
      });

      test('can be mapped to names', () {
        final modes = [BeatMode.normal, BeatMode.accent, BeatMode.silent];
        final names = modes.map((m) => m.name).toList();
        expect(names, ['normal', 'accent', 'silent']);
      });
    });

    group('BeatMode equality', () {
      test('same enum values are equal', () {
        expect(BeatMode.normal, BeatMode.normal);
        expect(BeatMode.accent, BeatMode.accent);
        expect(BeatMode.silent, BeatMode.silent);
      });

      test('different enum values are not equal', () {
        expect(BeatMode.normal, isNot(BeatMode.accent));
        expect(BeatMode.accent, isNot(BeatMode.silent));
        expect(BeatMode.silent, isNot(BeatMode.normal));
      });
    });
  });
}

BeatMode _cycleBeatMode(BeatMode current) {
  switch (current) {
    case BeatMode.normal:
      return BeatMode.accent;
    case BeatMode.accent:
      return BeatMode.silent;
    case BeatMode.silent:
      return BeatMode.normal;
  }
}
