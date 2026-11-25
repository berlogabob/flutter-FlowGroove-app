// Settings: ST-01 (web only), ST-06 (web only).
import 'dart:async';

import 'package:flowgroove/providers/theme_mode_provider.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/settings/app_settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'check.dart';

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AppSettingsScreen))).brightness;

void registerSettingsChecks() {
  check('ST-01', 'Theme switch light / dark', (tester) async {
    if (!kIsWeb) throw CheckSkip('web only check (per CHECKS.md brief); not run on $platformName');
    final c = await bootApp(tester);
    unawaited(appRouter.push('/main/settings'));
    await see(tester, find.byType(AppSettingsScreen), 'settings screen');
    ThemeMode mode() => c.read(themeModeProvider);
    try {
      await tapOn(tester, find.text('Dark'), 'Dark segment');
      await pause(tester, 600);
      if (mode() != ThemeMode.dark || _brightness(tester) != Brightness.dark) {
        fail('expected dark theme after tapping Dark; mode ${mode()}, brightness ${_brightness(tester)}');
      }
      await tapOn(tester, find.text('Light'), 'Light segment');
      await pause(tester, 600);
      if (mode() != ThemeMode.light || _brightness(tester) != Brightness.light) {
        fail('expected light theme after tapping Light; mode ${mode()}, brightness ${_brightness(tester)}');
      }
    } finally {
      await c.read(themeModeProvider.notifier).set(ThemeMode.light);
    }
  });

  check('ST-06', 'Web: reload keeps the session and the route', (tester) async {
    throw CheckSkip(
      kIsWeb
          ? 'a page reload ends the flutter drive session (the test runs inside the page), so the suite cannot observe the state after it'
          : 'web only check; not run on $platformName',
    );
  });
}
