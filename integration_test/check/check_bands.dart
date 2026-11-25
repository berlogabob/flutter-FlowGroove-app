// Bands area: BD-01 .. BD-07 (needs the second seeded user, see scripts/check_seed.py).
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/bands/band_about_screen.dart';
import 'package:flowgroove/screens/bands/band_invite_screen.dart';
import 'package:flowgroove/screens/bands/band_setlists_screen.dart';
import 'package:flowgroove/screens/bands/band_songs_screen.dart';
import 'package:flowgroove/screens/bands/create_band_screen.dart';
import 'package:flowgroove/screens/bands/join_band_screen.dart';
import 'package:flowgroove/screens/bands/my_bands_screen.dart';
import 'package:flowgroove/screens/bands/the_band_screen.dart';
import 'package:flowgroove/screens/setlists/create_setlist_screen.dart';
import 'package:flowgroove/screens/setlists/setlist_view_screen.dart';
import 'package:flowgroove/widgets/primary_action_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'check.dart';

DocumentReference<Map<String, dynamic>> _band(String id) => FirebaseFirestore.instance.doc('bands/$id');

Future<Map<String, dynamic>> _bandData(String id) => restDoc('bands/$id');

Future<void> _openBands(WidgetTester tester, String name) async {
  appRouter.go('/main/bands');
  await see(tester, find.byType(MyBandsScreen), 'bands screen');
  await see(tester, label(name), 'band "$name" in the bands list');
}

Future<void> openBandHub(WidgetTester tester, String name) async {
  await _openBands(tester, name);
  await tapOn(tester, label(name), 'band "$name" card');
  await see(tester, find.byType(TheBandScreen), 'band screen');
}

Future<void> _openAbout(WidgetTester tester, String name) async {
  await openBandHub(tester, name);
  await tapOn(tester, find.text('Members'), 'Members tile');
  await see(tester, find.byType(BandAboutScreen), 'band about screen');
}

void registerBandsChecks() {
  check('BD-01', 'Create a band', (tester) async {
    await bootApp(tester);
    const name = 'Check New Band';
    try {
      appRouter.go('/main/bands');
      await see(tester, find.byType(MyBandsScreen), 'bands screen');
      await tapOn(tester, find.byTooltip('Create band'), 'Create band button');
      await see(tester, find.byType(CreateBandScreen), 'create band screen');
      final fields = find.descendant(of: find.byType(CreateBandScreen), matching: find.byType(TextFormField));
      await typeInto(tester, fields.at(0), name, 'band name field');
      await typeInto(tester, fields.at(1), 'Made by the check suite', 'description field');
      await tapOn(tester, find.descendant(of: find.byType(CreateBandScreen), matching: find.text('Create Band')), 'Create Band button');
      await see(tester, find.text('Band Created!'), 'invite code dialog');
      final snap = await eventually(
        tester,
        () async => (await FirebaseFirestore.instance.collection('bands').where('memberUids', arrayContains: uid).where('name', isEqualTo: name).get()).docs,
        (d) => d.isNotEmpty,
        'saved band "$name"',
      );
      final data = snap.first.data();
      final code = data['inviteCode'] as String?;
      final members = (data['members'] as List?) ?? const [];
      if (code == null || code.length != 6) fail('expected a 6-character invite code; saved "$code"');
      if (data['createdBy'] != uid || members.length != 1 || (members.first as Map)['role'] != 'admin') {
        fail('expected the creator $uid as the only member with role admin; saved createdBy ${data['createdBy']}, members $members');
      }
      if (!found(find.text(code))) fail('expected the dialog to show the invite code "$code"; on screen: ${onScreen()}');
      await tapOn(tester, find.text('Done'), 'Done in the dialog');
      await see(tester, label(name), 'new band "$name" in the bands list');
    } finally {
      for (final d in (await FirebaseFirestore.instance.collection('bands').where('memberUids', arrayContains: uid).where('name', isEqualTo: name).get()).docs) {
        await d.reference.delete();
        await FirebaseFirestore.instance.doc('users/$uid/bands/${d.id}').delete();
      }
    }
  });

  check('BD-02', 'Invite code shown; join by code', (tester) async {
    await bootApp(tester);
    final problems = <String>[];
    try {
      // Invite screen of the admin band.
      await openBandHub(tester, adminBandName);
      await tapOn(tester, find.text('Member'), 'Member quick action');
      await see(tester, find.byType(BandInviteScreen), 'invite screen');
      if (!found(find.text('ADMIN1'))) problems.add('expected the invite screen to show the code ADMIN1; on screen: ${onScreen()}');
      // Join the other band by its code: Back twice (invite, band) to the bands list.
      await tapOn(tester, find.text('Back'), 'Back from the invite screen');
      await pause(tester, 600);
      await tapOn(tester, find.text('Back'), 'Back from the band screen');
      await see(tester, find.byType(MyBandsScreen), 'bands screen');
      await pause(tester, 600);
      await see(tester, find.text('Join band'), 'Join band button');
      final at = tester.getCenter(find.text('Join band').first);
      final top = tester.hitTestOnBinding(at).path.take(12).map((e) => e.target.runtimeType).join('>');
      await tapOn(tester, find.text('Join band'), 'Join band button');
      await expectSeen(tester, find.byType(JoinBandScreen), 'expected the join screen after tapping "Join band" (button at $at, hit $top)');
      await typeInto(tester, find.descendant(of: find.byType(JoinBandScreen), matching: find.byType(TextFormField)), joinBandCode, 'invite code field');
      await tapOn(tester, find.text('Find Band'), 'Find Band button');
      await see(tester, find.text(joinBandName), 'band name "$joinBandName" found by the code');
      await tapOn(tester, find.widgetWithText(ElevatedButton, 'Join Band'), 'Join Band button');
      final data = await eventually(
        tester,
        () => _bandData('check-band-join'),
        (d) => ((d['memberUids'] as List?) ?? const []).contains(uid),
        'seed user added to the band members',
      );
      final me = ((data['members'] as List).cast<Map>()).where((m) => m['uid'] == uid).toList();
      if (me.length != 1 || me.first['role'] != 'editor') problems.add('expected the joiner as editor; saved $me');
      await see(tester, label(joinBandName), 'joined band in the bands list');
      if (problems.isNotEmpty) fail(problems.join('; '));
    } finally {
      try {
        await FirebaseFunctions.instance.httpsCallable('updateBandMember').call({'bandId': 'check-band-join', 'targetUid': uid, 'action': 'remove'});
      } catch (_) {}
    }
  });

  check('BD-03', 'Join by deep link', (tester) async {
    await bootApp(tester);
    try {
      // What opening https://.../join?code=LINK77 does inside the app.
      appRouter.go('/join?code=LINK77');
      await see(tester, find.byType(JoinBandScreen), 'join screen from the deep link');
      await expectSeen(tester, find.text('Check Link Band'), 'expected the band "Check Link Band" loaded from the link code', seconds: 15);
      await tapOn(tester, find.widgetWithText(ElevatedButton, 'Join Band'), 'Join Band button');
      final data = await eventually(
        tester,
        () => _bandData('check-band-link'),
        (d) => ((d['memberUids'] as List?) ?? const []).contains(uid),
        'seed user added to the band members',
      );
      if (!((data['editorUids'] as List?) ?? const []).contains(uid)) fail('expected the joiner among editorUids; saved ${data['editorUids']}');
      await see(tester, find.byType(MyBandsScreen), 'bands screen after joining');
      await see(tester, label('Check Link Band'), 'joined band in the bands list');
      checkNote = 'driven through the router location (/join?code=...), not an OS link intent';
    } finally {
      try {
        await FirebaseFunctions.instance.httpsCallable('updateBandMember').call({'bandId': 'check-band-link', 'targetUid': uid, 'action': 'remove'});
      } catch (_) {}
    }
  });

  check('BD-04', 'Band songs: add from library', (tester) async {
    await bootApp(tester);
    final songs = FirebaseFirestore.instance.collection('bands/$adminBandId/songs');
    try {
      await openSongPage(tester, seedSongTitles.first);
      await menuAction(tester, 'Add to band…');
      await see(tester, find.text('Choose the band to save "${seedSongTitles.first}" to'), 'band picker');
      await tapOn(tester, find.widgetWithText(ListTile, adminBandName), 'band "$adminBandName" in the picker');
      await see(tester, find.text('Added "${seedSongTitles.first}" to band'), 'snackbar "Added ... to band"');
      final snap = await eventually(
        tester,
        () async => (await songs.where('title', isEqualTo: seedSongTitles.first).get()).docs,
        (d) => d.isNotEmpty,
        'song copied into the band library',
      );
      final copy = snap.first.data();
      if (copy['originalOwnerId'] != uid || '${copy['contributedBy']}'.isEmpty) {
        fail('expected originalOwnerId $uid and a contributedBy name on the band copy; saved ${copy['originalOwnerId']}, "${copy['contributedBy']}"');
      }
      // And the band's song list shows it.
      await openBandHub(tester, adminBandName);
      await tapOn(tester, find.text('Songs'), 'Songs tile');
      await see(tester, find.byType(BandSongsScreen), 'band songs screen');
      await expectSeen(tester, label(seedSongTitles.first), 'expected "${seedSongTitles.first}" in the band songs list');
    } finally {
      for (final d in (await songs.where('title', isEqualTo: seedSongTitles.first).get()).docs) {
        await d.reference.delete();
      }
    }
  });

  check('BD-05', 'Band setlists: create, view', (tester) async {
    await bootApp(tester);
    const name = 'Check Band Setlist';
    final setlists = FirebaseFirestore.instance.collection('bands/$adminBandId/setlists');
    try {
      await openBandHub(tester, adminBandName);
      await tapOn(tester, find.text('Setlists'), 'Setlists tile');
      await see(tester, find.byType(BandSetlistsScreen), 'band setlists screen');
      await tapOn(tester, find.byTooltip('Create Band Setlist'), 'Create Band Setlist button');
      await see(tester, find.byType(CreateSetlistScreen), 'setlist editor');
      await typeInto(
        tester,
        find.descendant(of: find.byType(CreateSetlistScreen), matching: find.byType(TextFormField)).first,
        name,
        'setlist name field',
      );
      await tapOn(tester, find.text('Add'), 'Add songs button');
      await see(tester, find.text('Select Songs (0)'), 'song picker');
      await tapOn(tester, find.widgetWithText(CheckboxListTile, 'Band Song One'), 'band song in the picker');
      await tapOn(tester, find.text('Done'), 'Done in the picker');
      await pause(tester, 500);
      await tapOn(
        tester,
        find.descendant(of: find.byType(PrimaryActionBar), matching: find.text('Create Setlist')),
        'Create Setlist button',
      );
      final snap = await eventually(
        tester,
        () async => (await setlists.where('name', isEqualTo: name).get()).docs,
        (d) => d.isNotEmpty,
        'band setlist saved under the band',
      );
      final items = (snap.first.data()['items'] as List?) ?? const [];
      if (items.length != 1 || (items.first as Map)['songId'] != 'check-band-song') {
        fail('expected one item check-band-song; saved $items');
      }
      await see(tester, find.byType(BandSetlistsScreen), 'band setlists screen after saving');
      await tapOn(tester, label(name), 'setlist "$name" card');
      await see(tester, find.byType(SetlistViewScreen), 'setlist view');
      await expectSeen(tester, label('Band Song One'), 'expected the band song in the setlist view');
    } finally {
      for (final d in (await setlists.where('name', isEqualTo: name).get()).docs) {
        await d.reference.delete();
      }
    }
  });

  check('BD-06', 'Members: change role, remove', (tester) async {
    await bootApp(tester);
    const id = 'check-band-members';
    const member = 'Check Two';
    await _openAbout(tester, 'Check Members Band');
    await see(tester, find.text(member), 'member "$member" in the list');
    Future<void> openMemberSheet() async {
      await scrollTo(tester, find.text(member), find.byType(BandAboutScreen), 'member "$member"');
      await tapOn(tester, find.text(member), 'member "$member"');
    }

    final two = ((await _bandData(id))['members'] as List).cast<Map>().firstWhere((m) => m['email'] == seed2Email)['uid'] as String;
    await openMemberSheet();
    await tapOn(tester, find.text('Viewer role'), 'Viewer role');
    await see(tester, find.text('Updated role to Viewer'), 'snackbar "Updated role to Viewer"');
    final after = await eventually(
      tester,
      () => _bandData(id),
      (d) => !((d['editorUids'] as List?) ?? const []).contains(two),
      'member $two no longer an editor',
    );
    if (((after['adminUids'] as List?) ?? const []).contains(two)) fail('expected $two to be a viewer; saved adminUids ${after['adminUids']}');
    await snackbarsGone(tester); // it would sit over the bottom row of the next sheet
    await openMemberSheet();
    await tapOn(tester, find.text('Remove from band'), 'Remove from band');
    await expectSeen(tester, find.text('Remove member'), 'expected the "Remove member" confirmation after tapping "Remove from band"');
    await tapOn(tester, find.widgetWithText(TextButton, 'Remove'), 'Remove in the dialog');
    final removed = await eventually(
      tester,
      () => _bandData(id),
      (d) => !((d['memberUids'] as List?) ?? const []).contains(two),
      'member $two removed from the band',
    );
    if ((removed['members'] as List).length != 1) fail('expected 1 member left; saved ${(removed['members'] as List).length}');
    await pause(tester, 600);
    if (found(find.text(member))) fail('"$member" is still listed after being removed');
  });

  check('BD-07', 'Edit band name and description', (tester) async {
    await bootApp(tester);
    final before = await _bandData(adminBandId);
    const name = 'Check Renamed Band';
    final problems = <String>[];
    final ref = FirebaseFirestore.instance.doc('users/$uid/bands/$adminBandId');

    // One edit dialog: type, Save, then compare what the user sees with what is stored.
    Future<void> edit(String menuRow, String field, String value) async {
      await snackbarsGone(tester);
      await menuAction(tester, menuRow);
      await see(tester, find.byType(AlertDialog), '$menuRow dialog');
      await typeInto(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)), value, '$field field');
      await tapOn(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Save')), 'Save in the dialog');
      await pause(tester, 800);
      final stored = (await _bandData(adminBandId))[field];
      final personal = (await ref.get()).data()?[field];
      if (stored != value) {
        problems.add('$menuRow: expected bands/$adminBandId $field "$value" after Save; stored "$stored" (users/$uid/bands/$adminBandId $field: "$personal")');
      }
      if (!found(find.byType(TheBandScreen))) {
        // Save pops the State's own context (the band screen) instead of the dialog's; the dialog is left over
        // the bands list with a disposed controller, and on Android the app then shows its error screen.
        problems.add('$menuRow: expected only the dialog to close after Save; the band screen was popped instead (route ${appRouter.routerDelegate.currentConfiguration.uri}), dialog still open: ${found(find.byType(AlertDialog))}');
        fail(problems.join('; '));
      }
    }

    try {
      await openBandHub(tester, adminBandName);
      await edit('Edit Band Name', 'name', name);
      if (!found(find.byType(TheBandScreen))) {
        problems.add('after Save the band screen is gone (route ${appRouter.routeInformationProvider.value.uri})');
        await openBandHub(tester, before['name'] as String);
      }
      await edit('Edit Description', 'description', 'New description');
      if (problems.isNotEmpty) fail(problems.join('; '));
    } finally {
      // The rules refuse a client write to bands/, so restore through the emulator's admin REST API.
      final desc = before['description'];
      await http.patch(
        Uri.parse('http://$emulatorHost:8080/v1/projects/repsync-app-8685c/databases/(default)/documents/bands/$adminBandId?updateMask.fieldPaths=name&updateMask.fieldPaths=description'),
        headers: {'Authorization': 'Bearer owner'},
        body: jsonEncode({
          'fields': {
            'name': {'stringValue': before['name']},
            if (desc != null) 'description': {'stringValue': desc},
          },
        }),
      );
      await ref.set({'bandId': adminBandId});
    }
  });
}
