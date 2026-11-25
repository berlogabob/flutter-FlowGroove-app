// Settings: ST-01 (web only), ST-02, ST-04, ST-05, ST-06.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowgroove/providers/theme_mode_provider.dart';
import 'package:flowgroove/screens/settings/api_access_screen.dart';
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

  check('ST-02', 'API access: create and revoke a key', (tester) async {
    await bootApp(tester);
    unawaited(appRouter.push('/main/settings'));
    await see(tester, find.byType(AppSettingsScreen), 'settings screen');
    await scrollTo(tester, find.text('AI access (MCP)'), find.byType(AppSettingsScreen), 'AI access row');
    await tapOn(tester, find.text('AI access (MCP)'), 'AI access row');
    await see(tester, find.byType(ApiAccessScreen), 'API access screen');
    await tapOn(tester, find.text('New key'), 'New key button');
    await see(tester, find.text('New API key'), 'new key sheet');
    await typeInto(tester, find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextFormField)), 'Check Key', 'label field');
    await tapOn(tester, find.text('Create'), 'Create button');
    await expectSeen(tester, find.text('Your API key'), 'expected the one-time key dialog after Create', seconds: 20);
    await tapOn(tester, find.text('Copy & close'), 'Copy & close');
    await pause(tester, 800);
    if (found(find.text('Your API key'))) {
      if (!kIsWeb) fail('expected "Copy & close" to close the key dialog');
      checkNote = 'web: Chrome refuses the clipboard write under automation, so "Copy & close" leaves the dialog open (the app awaits Clipboard.setData before closing); test limitation, closed by hand. ';
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await pause(tester, 600);
    }
    await expectSeen(tester, find.text('Check Key'), 'expected the new key "Check Key" in the list', seconds: 15);
    await tapOn(tester, find.byTooltip('Revoke'), 'Revoke button');
    await see(tester, find.text('Revoke key'), 'revoke dialog');
    await tapOn(tester, find.widgetWithText(TextButton, 'Revoke'), 'Revoke in the dialog');
    await pumpUntil(tester, () => !found(find.text('Check Key')), timeout: const Duration(seconds: 15), what: 'key to leave the list');
  });

  check('ST-04', 'Support sheet opens', (tester) async {
    await bootApp(tester);
    unawaited(appRouter.push('/main/settings'));
    await see(tester, find.byType(AppSettingsScreen), 'settings screen');
    await scrollTo(tester, find.text('Contact support'), find.byType(AppSettingsScreen), 'Contact support row');
    await tapOn(tester, find.text('Contact support'), 'Contact support row');
    await expectSeen(tester, find.text('Telegram'), 'expected the support sheet with a Telegram row');
    await expectSeen(tester, find.text('WhatsApp'), 'expected the support sheet with a WhatsApp row');
  });

  check('ST-05', 'App works offline for cached songs and syncs after', (tester) async {
    await bootApp(tester);
    const title = 'Check Song Alpha';
    final fs = FirebaseFirestore.instance;
    final before = (await restDoc('users/$uid/songs/$seedSongId'))['artist'];
    await openSongsTab(tester);
    await see(tester, label(title), 'seeded song in the list');
    await fs.disableNetwork();
    try {
      await openSongPage(tester, title);
      await tapOn(tester, find.text('Edit'), 'Edit tab on the song page');
      final field = find.descendant(of: find.byType(Form), matching: find.byType(TextFormField));
      await see(tester, field.at(1), 'artist field');
      await typeInto(tester, field.at(1), 'Offline Artist', 'artist field');
      await tapOn(tester, find.text('Save Changes'), 'Save Changes button');
      await pause(tester, 3000);
      final during = (await restDoc('users/$uid/songs/$seedSongId'))['artist'];
      if (during != before) fail('expected the server unchanged while offline; server has "$during"');
      final local = ((await fs.doc('users/$uid/songs/$seedSongId').get(const GetOptions(source: Source.cache))).data() ?? {})['artist'];
      if (local != 'Offline Artist') fail('expected the offline edit in the local cache; cache has "$local"; on screen: ${onScreen()}');
      await fs.enableNetwork();
      await eventually(
        tester,
        () async => (await restDoc('users/$uid/songs/$seedSongId'))['artist'],
        (a) => a == 'Offline Artist',
        'offline edit synced to the server',
        show: (a) => '"$a"',
      );
    } finally {
      await fs.enableNetwork();
      await fs.doc('users/$uid/songs/$seedSongId').update({'artist': before});
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
