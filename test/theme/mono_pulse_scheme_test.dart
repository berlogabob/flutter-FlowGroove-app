import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonoPulse ColorScheme derived slots (#149 cyan regression)', () {
    // ColorScheme's getters fall back secondaryContainer→secondary and
    // copyWith bakes the BASE scheme's getter value in — leaving the
    // *Container slots unset leaked legacy teal #03DAC6 into every
    // FilledButton.tonal in 0.17.0.
    const legacyTeal = Color(0xFF03DAC6);

    for (final (name, themeOf) in [
      ('dark', () => MonoPulseTheme.theme),
      ('light', () => MonoPulseTheme.lightTheme),
    ]) {
      test('$name theme has no legacy teal in any scheme slot', () {
        final s = themeOf().colorScheme;
        final slots = {
          'secondary': s.secondary,
          'secondaryContainer': s.secondaryContainer,
          'onSecondaryContainer': s.onSecondaryContainer,
          'tertiary': s.tertiary,
          'tertiaryContainer': s.tertiaryContainer,
          'onTertiaryContainer': s.onTertiaryContainer,
        };
        for (final entry in slots.entries) {
          expect(
            entry.value,
            isNot(legacyTeal),
            reason: '${entry.key} leaked the legacy ColorScheme default',
          );
        }
        expect(s.secondaryContainer, s.secondary);
      });
    }
  });
}
