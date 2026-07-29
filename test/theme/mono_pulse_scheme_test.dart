import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonoPulse ColorScheme derived slots (#149 cyan regression)', () {
    // ColorScheme's getters fall back secondaryContainer→secondary and
    // copyWith bakes the BASE scheme's getter value in — leaving the
    // *Container slots unset leaked legacy teal #03DAC6 into every
    // FilledButton.tonal in 0.17.0.
    const legacyTeal = Color(0xFF03DAC6);

    for (final (name, palette, brightness) in [
      ('dark', MonoPulsePalette.dark, Brightness.dark),
      ('light', MonoPulsePalette.light, Brightness.light),
    ]) {
      test('$name theme has no legacy teal in any scheme slot', () {
        // schemeFor is the exact scheme _build puts into ThemeData; testing
        // it directly avoids GoogleFonts, which tests cannot load.
        final s = MonoPulseTheme.schemeFor(palette, brightness);
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
