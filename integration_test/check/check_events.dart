// Rehearsals and events: EV-01 .. EV-05.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowgroove/models/rehearsal.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/bands/rehearsals/rehearsal_detail_screen.dart';
import 'package:flowgroove/screens/bands/rehearsals/rehearsal_edit_screen.dart';
import 'package:flowgroove/screens/bands/rehearsals/rehearsals_list_screen.dart';
import 'package:flowgroove/screens/setlists/event_kit_editor_screen.dart';
import 'package:flowgroove/screens/setlists/setlist_view_screen.dart';
import 'package:flowgroove/screens/setlists/setlists_list_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'check.dart';
import 'check_bands.dart';

CollectionReference<Map<String, dynamic>> get _rehearsals => FirebaseFirestore.instance.collection('bands/$adminBandId/rehearsals');

Future<void> _openRehearsals(WidgetTester tester) async {
  await openBandHub(tester, adminBandName);
  await tapOn(tester, find.text('Rehearsals'), 'Rehearsals quick action');
  await see(tester, find.byType(RehearsalsListScreen), 'rehearsals screen');
}

Future<String> _putRehearsal(String id, String title, {int slots = 2}) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day).add(const Duration(days: 5));
  final r = Rehearsal(
    id: id,
    bandId: adminBandId,
    createdBy: uid,
    title: title,
    createdAt: now,
    updatedAt: now,
    candidateSlots: [
      for (var i = 0; i < slots; i++)
        CandidateSlot(id: 'slot-$i', startTime: day.add(Duration(days: i, hours: 19)), endTime: day.add(Duration(days: i, hours: 21))),
    ],
  );
  await _rehearsals.doc(id).set(r.toJson());
  return id;
}

Future<void> _openRehearsal(WidgetTester tester, String title) async {
  await _openRehearsals(tester);
  await tapOn(tester, label(title), 'rehearsal "$title" in the list');
  await see(tester, find.byType(RehearsalDetailScreen), 'rehearsal detail');
}

const _kitSetlist = 'check-sl-kit';

Future<void> _putKitSetlist() {
  final now = DateTime.now();
  return FirebaseFirestore.instance.doc('users/$uid/setlists/$_kitSetlist').set(
    Setlist(
      id: _kitSetlist,
      bandId: '',
      name: 'Check Kit Setlist',
      createdAt: now,
      updatedAt: now,
      songIds: const ['check-song-1'],
      items: const [SetlistItem(id: 'k1', songId: 'check-song-1')],
    ).toJson(),
  );
}

Future<void> _openKit(WidgetTester tester) async {
  appRouter.go('/main/setlists');
  await see(tester, find.byType(SetlistsListScreen), 'setlists screen');
  await tapOn(tester, label('Check Kit Setlist'), 'setlist "Check Kit Setlist" card');
  await see(tester, find.byType(SetlistViewScreen), 'setlist view');
  await menuAction(tester, 'Event kit');
  await see(tester, find.byType(EventKitEditorScreen), 'event kit editor');
}

/// Leaves the editor the way a user does (its Back button). It is pushed on the root navigator, and tearing the
/// app down with it still open breaks the page on web for every later check.
Future<void> _leaveKit(WidgetTester tester) async {
  if (found(find.byType(EventKitEditorScreen)) && found(find.text('Back'))) {
    await tester.tap(find.text('Back').first);
    await pause(tester, 800);
  }
  // Also close the setlist page under the editor while the Setlists tab is on screen. Left open, the next check's tap on
  // the same setlist card (EV-05 after EV-04) spins Chrome's renderer forever and the whole web run dies.
  appRouter.go('/main/setlists');
  await pause(tester, 800);
}

Future<Map<String, dynamic>> _kit() async => (((await FirebaseFirestore.instance.doc('users/$uid/setlists/$_kitSetlist').get()).data() ?? {})['eventKit'] as Map?)?.cast<String, dynamic>() ?? {};

Future<void> _addPerson(WidgetTester tester, String name, String role) async {
  await scrollTo(tester, find.text('Add person'), find.byType(EventKitEditorScreen), 'Add person chip');
  await tapOn(tester, find.text('Add person'), 'Add person chip');
  await see(tester, find.text('Add crew / guest'), 'add person sheet');
  final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextFormField));
  await typeInto(tester, fields.at(0), name, 'name field');
  await typeInto(tester, fields.at(1), role, 'role field');
  await scrollTo(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Add')), find.byType(BottomSheet), 'Add button');
  await tapOn(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Add')), 'Add in the sheet');
  await see(tester, find.text(name), 'person "$name" in the crew list');
}

void registerEventsChecks() {
  check('EV-01', 'Create a rehearsal', (tester) async {
    await bootApp(tester);
    const title = 'Check New Rehearsal';
    try {
      await _openRehearsals(tester);
      await tapOn(tester, find.byTooltip('Propose rehearsal'), 'Propose rehearsal button');
      await see(tester, find.byType(RehearsalEditScreen), 'new rehearsal form');
      await typeInto(tester, find.descendant(of: find.byType(RehearsalEditScreen), matching: find.byType(TextFormField)).first, title, 'title field');
      await tapOn(tester, find.text('Add time option'), 'Add time option');
      for (final step in ['date', 'start time', 'end time']) {
        await see(tester, find.text('OK'), 'OK in the $step picker');
        await tapOn(tester, find.text('OK'), 'OK in the $step picker');
        await pause(tester, 500);
      }
      final save = find.descendant(of: find.byType(RehearsalEditScreen), matching: find.text('Save'));
      await scrollTo(tester, save, find.byType(RehearsalEditScreen), 'Save button');
      await tapOn(tester, save, 'Save button');
      final snap = await eventually(
        tester,
        () async => (await _rehearsals.where('title', isEqualTo: title).get()).docs,
        (d) => d.isNotEmpty,
        'rehearsal "$title" saved under the band',
      );
      final data = snap.first.data();
      final slots = (data['candidateSlots'] as List?) ?? const [];
      if (slots.length != 1 || data['status'] != 'collecting' || data['createdBy'] != uid) {
        fail('expected 1 time option, status collecting, createdBy $uid; saved ${slots.length} options, status ${data['status']}, createdBy ${data['createdBy']}');
      }
      await see(tester, find.byType(RehearsalsListScreen), 'rehearsals list after saving');
      await expectSeen(tester, label(title), 'expected the new rehearsal "$title" in the list');
    } finally {
      for (final d in (await _rehearsals.where('title', isEqualTo: title).get()).docs) {
        await d.reference.delete();
      }
    }
  });

  check('EV-02', 'Rehearsal detail: answer, suggest another time', (tester) async {
    await bootApp(tester);
    const id = 'check-rehearsal-vote';
    await _putRehearsal(id, 'Check Vote Rehearsal');
    final vote = _rehearsals.doc(id).collection('votes').doc(uid);
    try {
      await _openRehearsal(tester, 'Check Vote Rehearsal');
      await tapOn(tester, find.text('Can').first, 'Can on the first option');
      await tapOn(tester, find.text('Maybe').last, 'Maybe on the second option');
      final answers = await eventually(
        tester,
        () async => (((await vote.get()).data() ?? {})['answers'] as Map?)?.cast<String, dynamic>() ?? {},
        (a) => a.length == 2,
        'two answers saved',
        show: (a) => '$a',
      );
      if (answers['slot-0'] != 'can' || answers['slot-1'] != 'maybe') {
        fail('expected answers slot-0 can, slot-1 maybe; saved $answers');
      }
      final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Can').first);
      if (!chip.selected) fail('expected the first "Can" chip to show as selected after answering');
      await scrollTo(tester, find.text('None of these work — suggest a time'), find.byType(RehearsalDetailScreen), 'suggest a time button');
      await tapOn(tester, find.text('None of these work — suggest a time'), 'suggest a time button');
      await see(tester, find.text('Suggest a different time'), 'suggest dialog');
      await typeInto(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Sunday 18:00?', 'suggestion field');
      await tapOn(tester, find.text('Send'), 'Send button');
      final comment = await eventually(
        tester,
        () async => (await vote.get()).data()?['comment'],
        (c) => c == 'Sunday 18:00?',
        'suggestion saved',
        show: (c) => '"$c"',
      );
      if (comment != 'Sunday 18:00?') fail('expected the comment "Sunday 18:00?"; saved "$comment"');
    } finally {
      await vote.delete();
      await _rehearsals.doc(id).delete();
    }
  });

  check('EV-03', 'Edit a rehearsal', (tester) async {
    await bootApp(tester);
    const id = 'check-rehearsal-edit';
    await _putRehearsal(id, 'Check Edit Rehearsal', slots: 1);
    try {
      await _openRehearsal(tester, 'Check Edit Rehearsal');
      await scrollTo(tester, find.text('Edit details'), find.byType(RehearsalDetailScreen), 'Edit details button');
      await tapOn(tester, find.text('Edit details'), 'Edit details button');
      await see(tester, find.byType(RehearsalEditScreen), 'edit form');
      await typeInto(tester, find.descendant(of: find.byType(RehearsalEditScreen), matching: find.byType(TextFormField)).first, 'Check Edited Rehearsal', 'title field');
      FocusManager.instance.primaryFocus?.unfocus(); // close the keyboard: its animation shifts the list under the tap
      await pause(tester, 600);
      await scrollTo(tester, find.text('Custom place'), find.byType(RehearsalEditScreen), 'Custom place chip');
      await tapOn(tester, find.text('Custom place'), 'Custom place chip');
      final location = find.ancestor(of: find.text('e.g. Studio A'), matching: find.byType(TextFormField));
      // The Location field only exists once "Custom place" is selected; it sits below the chips in a lazy list.
      await pumpUntil(tester, () => found(location), what: 'Location field after selecting Custom place', timeout: const Duration(seconds: 5));
      for (var i = 0; i < 10 && !found(location); i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -150));
        await pause(tester, 200);
      }
      await typeInto(tester, location, 'Garage 7', 'location field');
      final save = find.descendant(of: find.byType(RehearsalEditScreen), matching: find.text('Save'));
      await scrollTo(tester, save, find.byType(RehearsalEditScreen), 'Save button');
      await tapOn(tester, save, 'Save button');
      final data = await eventually(
        tester,
        () async => (await _rehearsals.doc(id).get()).data() ?? {},
        (d) => d['title'] == 'Check Edited Rehearsal',
        'edited title saved',
        show: (d) => '"${d['title']}"',
      );
      if (data['location'] != 'Garage 7') fail('expected location "Garage 7"; saved "${data['location']}"');
      await see(tester, find.byType(RehearsalDetailScreen), 'detail after saving');
      await expectSeen(tester, label('Check Edited Rehearsal'), 'expected the detail screen to show the new title');
      await expectSeen(tester, find.text('Garage 7'), 'expected the detail screen to show the location');
    } finally {
      await _rehearsals.doc(id).delete();
    }
  });

  check('EV-04', 'Event kit editor: add performer, kit item', (tester) async {
    await bootApp(tester);
    await _putKitSetlist();
    try {
      await _openKit(tester);
      await _addPerson(tester, 'Check Roadie', 'Roadie');
      await scrollTo(tester, find.text('Add rider item'), find.byType(EventKitEditorScreen), 'Add rider item chip');
      await tapOn(tester, find.text('Add rider item'), 'Add rider item chip');
      await typeInto(tester, find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextFormField)), 'XLR cables x4', 'rider item field');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pause(tester, 600);
      await see(tester, find.textContaining('XLR cables x4'), 'rider item in the list');
      final kit = await eventually(
        tester,
        () => _kit(),
        (k) => ((k['people'] as List?) ?? const []).isNotEmpty && ((k['rider'] as List?) ?? const []).isNotEmpty,
        'person and rider item saved',
        show: (k) => '$k',
      );
      final person = ((kit['people'] as List).first as Map);
      if (person['name'] != 'Check Roadie' || person['role'] != 'Roadie') fail('expected the person Check Roadie / Roadie; saved $person');
      if (((kit['rider'] as List).first as Map)['label'] != 'XLR cables x4') fail('expected rider item "XLR cables x4"; saved ${kit['rider']}');
    } finally {
      await _leaveKit(tester);
      await FirebaseFirestore.instance.doc('users/$uid/setlists/$_kitSetlist').delete();
    }
  });

  check('EV-05', 'Event share link: create, revoke', (tester) async {
    await bootApp(tester);
    await _putKitSetlist();
    try {
      await _openKit(tester);
      await _addPerson(tester, 'Check Guest', 'Photographer');
      await pause(tester, 1000);
      await snackbarsGone(tester);
      await scrollTo(tester, find.byTooltip('Share this event with Check Guest'), find.byType(EventKitEditorScreen), 'share link button');
      await tapOn(tester, find.byTooltip('Share this event with Check Guest'), 'share link button');
      // The link is copied to the clipboard; Chrome refuses clipboard writes under automation.
      final copied = find.textContaining('Link for Check Guest copied');
      try {
        await see(tester, copied, 'link snackbar', seconds: 10);
      } on TimeoutException {
        if (!kIsWeb) fail('expected the snackbar "Link for Check Guest copied"; on screen: ${onScreen()}');
        checkNote = 'web: the snackbar says "Could not create the link" because Chrome refuses the clipboard write under automation (the link itself is created server-side); test limitation. ';
      }
      await snackbarsGone(tester);
      // The roster's "Share links inventory" chip is gated on _canManageShares, which for a personal
      // setlist needs ownerUid; no caller of EventKitEditorScreen passes it for the owner's own setlist.
      if (!found(find.text('Share links inventory'))) {
        await tester.ensureVisible(find.text('Crew & guests'));
        await pause(tester, 300);
        if (!found(find.text('Share links inventory'))) {
          fail('expected the "Share links inventory" chip in Crew & guests for the owner of a personal setlist (needed to revoke the link just created); not shown; on screen: ${onScreen()}');
        }
      }
      await tapOn(tester, find.text('Share links inventory'), 'Share links inventory chip');
      await see(tester, find.text('Check Guest'), 'the share for Check Guest in the inventory', seconds: 15);
      if (!found(find.textContaining('active'))) fail('expected the new share to be active; on screen: ${onScreen()}');
      await tapOn(tester, find.byTooltip('Revoke Check Guest'), 'Revoke button');
      await see(tester, find.text('Revoke share link?'), 'revoke confirmation');
      await tapOn(tester, find.widgetWithText(TextButton, 'Revoke'), 'Revoke in the dialog');
      await expectSeen(tester, find.textContaining('revoked'), 'expected the share to show as revoked', seconds: 15);
      if (found(find.byTooltip('Revoke Check Guest'))) fail('the Revoke button is still offered after revoking');
    } finally {
      await _leaveKit(tester);
      await FirebaseFirestore.instance.doc('users/$uid/setlists/$_kitSetlist').delete();
    }
  });
}
