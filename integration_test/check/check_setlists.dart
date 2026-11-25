// Setlists area: SL-01, SL-02, SL-03, SL-05, SL-06.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/setlists/create_setlist_screen.dart';
import 'package:flowgroove/screens/setlists/setlist_view_screen.dart';
import 'package:flowgroove/screens/setlists/setlists_list_screen.dart';
import 'package:flowgroove/widgets/primary_action_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'check.dart';

const _songIds = ['check-song-1', 'check-song-2', 'check-song-3'];

CollectionReference<Map<String, dynamic>> get _setlists =>
    FirebaseFirestore.instance.collection('users/$uid/setlists');

Future<Map<String, dynamic>?> _byName(String name) async {
  final q = await _setlists.where('name', isEqualTo: name).get();
  return q.docs.isEmpty ? null : q.docs.first.data();
}

Future<void> _deleteByName(String name) async {
  final q = await _setlists.where('name', isEqualTo: name).get();
  for (final d in q.docs) {
    await d.reference.delete();
  }
}

/// Titles of the song rows of a stored setlist, in order ("|break" for breaks).
List<String> _stored(Map<String, dynamic> data) => [
  for (final i in (data['items'] as List? ?? const []))
    if ((i as Map)['type'] == 'break') '|break' else '${i['songId']}',
];

Future<void> _putSetlist(
  ProviderContainer c,
  String id,
  String name,
  List<String> songIds,
) {
  final now = DateTime.now();
  return c.read(firestoreProvider).saveSetlist(
    Setlist(
      id: id,
      bandId: '',
      name: name,
      createdAt: now,
      updatedAt: now,
      songIds: songIds,
      items: [
        for (var i = 0; i < songIds.length; i++)
          SetlistItem(id: 'item-$id-$i', songId: songIds[i]),
      ],
    ),
    uid: uid,
  );
}

Future<void> _openSetlists(WidgetTester tester, String name) async {
  appRouter.go('/main/setlists');
  await see(tester, find.byType(SetlistsListScreen), 'setlists screen');
  await see(tester, label(name), 'setlist "$name" in the list');
}

Future<void> _openView(WidgetTester tester, String name) async {
  await _openSetlists(tester, name);
  await tapOn(tester, label(name), 'setlist "$name" card');
  await see(tester, find.byType(SetlistViewScreen), 'setlist view');
}

Future<void> _openEdit(WidgetTester tester, String name) async {
  await _openView(tester, name);
  await menuAction(tester, 'Edit Setlist');
  await see(tester, find.byType(CreateSetlistScreen), 'setlist editor');
}

Finder _saveButton(String text) => find.descendant(
  of: find.byType(PrimaryActionBar),
  matching: find.text(text),
);

Finder get _nameField => find.descendant(
  of: find.byType(CreateSetlistScreen),
  matching: find.byType(TextFormField),
).first;

Future<void> _pickSongs(WidgetTester tester, List<String> titles) async {
  await tapOn(tester, find.text('Add'), 'Add songs button');
  await see(tester, find.text('Select Songs (0)'), 'song picker');
  for (final t in titles) {
    await tapOn(tester, find.widgetWithText(CheckboxListTile, t), 'song "$t" in the picker');
  }
  await tapOn(tester, find.text('Done'), 'Done in the picker');
  await pause(tester, 500);
}

double _y(WidgetTester tester, String t) => tester.getTopLeft(label(t).first).dy;

void registerSetlistsChecks() {
  check('SL-01', 'Create a setlist with songs', (tester) async {
    await bootApp(tester);
    const name = 'Check Create Setlist';
    try {
      await _deleteByName(name);
      appRouter.go('/main/setlists');
      await see(tester, find.byType(SetlistsListScreen), 'setlists screen');
      await tapOn(tester, find.byTooltip('Create Setlist'), 'Create Setlist button');
      await see(tester, find.byType(CreateSetlistScreen), 'setlist editor');
      await typeInto(tester, _nameField, name, 'setlist name field');
      await _pickSongs(tester, [seedSongTitles[0], seedSongTitles[1]]);
      await see(tester, find.text('Songs (2)'), 'songs counter "Songs (2)"');
      await tapOn(tester, _saveButton('Create Setlist'), 'Create Setlist button');
      final data = await eventually(
        tester,
        () => _byName(name),
        (d) => d != null,
        'setlist "$name" saved to Firestore',
        seconds: 8,
        show: (d) => 'no document',
      );
      final items = _stored(data!);
      if (items.join(',') != _songIds.take(2).join(',')) {
        fail('expected saved songs ${_songIds.take(2)}; saved $items');
      }
      await _openSetlists(tester, name);
    } finally {
      await _deleteByName(name);
    }
  });

  check('SL-02', 'Reorder songs, add a break', (tester) async {
    final c = await bootApp(tester);
    const id = 'check-sl-reorder';
    const name = 'Check Reorder Setlist';
    try {
      await _putSetlist(c, id, name, _songIds);
      await _openEdit(tester, name);
      for (final t in seedSongTitles) {
        await see(tester, label(t), 'song "$t" in the editor');
      }
      await pause(tester, 800);
      final ys = [for (final t in seedSongTitles) _y(tester, t)];
      final startY = ys[2];
      final gesture = await tester.startGesture(tester.getCenter(label(seedSongTitles[2]).first));
      await pause(tester, 800); // long press arms the drag
      final distance = startY - ys[0] + 20;
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, -distance / 20));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await gesture.up();
      await pause(tester, 600);
      final order = [
        for (final t in seedSongTitles) t,
      ]..sort((a, b) => _y(tester, a).compareTo(_y(tester, b)));
      if (order.first != seedSongTitles[2]) {
        fail(
          'after long-press dragging Gamma above Alpha expected the first row Gamma; '
          'observed order ${order.map((t) => t.split(' ').last).join(', ')} '
          '(row tops before $ys, after ${[for (final t in seedSongTitles) _y(tester, t)]}, dragged ${distance.round()} px up)',
        );
      }
      await tapOn(tester, find.widgetWithText(TextButton, 'Break'), 'Break button');
      await see(tester, find.text('Set change'), 'break picker');
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'Set change'), 'Set change chip');
      await tapOn(tester, find.text('Save'), 'Save in the break picker');
      await pause(tester, 400);
      await see(tester, find.text('Set change'), 'break row "Set change"');
      await tapOn(tester, _saveButton('Save Changes'), 'Save Changes button');
      final data = await eventually(
        tester,
        () async => (await _setlists.doc(id).get()).data()!,
        (d) => _stored(d).length == 4,
        'saved setlist with 3 songs and a break',
        seconds: 8,
        show: (d) => 'saved ${_stored(d)}',
      );
      final saved = _stored(data);
      final songsOnly = saved.where((e) => e != '|break').toList();
      if (songsOnly.join(',') != 'check-song-3,check-song-1,check-song-2') {
        fail('expected saved song order check-song-3, check-song-1, check-song-2; saved $saved');
      }
      if (!saved.contains('|break')) fail('expected a break item; saved $saved');
    } finally {
      await _setlists.doc(id).delete();
    }
  });

  check('SL-03', 'Edit and save; discard asks', (tester) async {
    final c = await bootApp(tester);
    const id = 'check-sl-edit';
    const name = 'Check Edit Setlist';
    const renamed = 'Check Edit Setlist 2';
    try {
      await _putSetlist(c, id, name, _songIds.take(2).toList());
      // Dirty form + Back must ask.
      await _openEdit(tester, name);
      await typeInto(tester, _nameField, 'Check Discarded Name', 'setlist name field');
      await tapOn(tester, find.text('Back'), 'Back button in the bottom bar');
      await pause(tester, 600);
      if (!found(find.text('Discard Changes?'))) {
        // Tell a shell-button problem from a screen problem: try the system back too.
        var systemBack = 'n/a';
        final closed = !found(find.byType(CreateSetlistScreen));
        checkNote = 'shell Back ${closed ? 'closed the editor without asking' : 'did nothing'}';
        if (!closed) {
          await tester.binding.handlePopRoute();
          await pause(tester, 600);
          systemBack = found(find.text('Discard Changes?')) ? 'asks' : 'does not ask';
        } else {
          await menuAction(tester, 'Edit Setlist');
          await typeInto(tester, _nameField, 'Check Discarded Name', 'setlist name field');
          await tester.binding.handlePopRoute();
          await pause(tester, 600);
          systemBack = found(find.text('Discard Changes?')) ? 'asks' : 'does not ask';
        }
        fail(
          'shell Back: ${closed ? 'closed the editor silently' : 'did nothing'}; system back: $systemBack; '
          'expected a "Discard Changes?" dialog after editing the name and pressing Back; '
          'shell Back pop observed, editor still open: ${found(find.byType(CreateSetlistScreen))}',
        );
      }
      await tapOn(tester, find.text('Cancel'), 'Cancel in the discard dialog');
      if (!found(find.byType(CreateSetlistScreen))) fail('Cancel in the discard dialog closed the editor');
      // Discard leaves the stored name alone.
      await tapOn(tester, find.text('Back'), 'Back button in the bottom bar');
      await tapOn(tester, find.text('Discard'), 'Discard in the dialog');
      await pause(tester, 600);
      final kept = (await _setlists.doc(id).get()).data()!['name'];
      if (kept != name) fail('after Discard expected name "$name"; stored "$kept"');
      // Edit and save.
      if (!found(find.byType(CreateSetlistScreen))) {
        await menuAction(tester, 'Edit Setlist');
      }
      await see(tester, find.byType(CreateSetlistScreen), 'setlist editor');
      await typeInto(tester, _nameField, renamed, 'setlist name field');
      await tapOn(tester, _saveButton('Save Changes'), 'Save Changes button');
      await eventually(
        tester,
        () async => (await _setlists.doc(id).get()).data()!['name'] as String,
        (n) => n == renamed,
        'expected stored name "$renamed" after Save Changes',
        seconds: 8,
      );
    } finally {
      await _setlists.doc(id).delete();
    }
  });

  check('SL-05', 'Concert mode opens and steps through songs', (tester) async {
    final c = await bootApp(tester);
    const id = 'check-sl-concert';
    const name = 'Check Concert Setlist';
    try {
      await _putSetlist(c, id, name, _songIds.take(2).toList());
      await _openView(tester, name);
      await menuAction(tester, 'Concert mode');
      await see(tester, find.byTooltip('Next song'), 'Next song button (concert mode)');
      await see(tester, label(seedSongTitles[0]), 'first song title in concert mode');
      if (!found(label('120'))) fail('expected BPM 120 for the first song in concert mode');
      await tapOn(tester, find.byTooltip('Next song'), 'Next song button');
      await see(tester, label(seedSongTitles[1]), 'second song title in concert mode');
      if (!found(label('100'))) fail('expected BPM 100 for the second song after Next');
      await tapOn(tester, find.byTooltip('Previous song'), 'Previous song button');
      await see(tester, label(seedSongTitles[0]), 'first song title again after Previous');
      await tapOn(tester, find.byTooltip('Exit Concert Mode'), 'Exit Concert Mode');
      await see(tester, find.byType(SetlistViewScreen), 'setlist view after exit');
    } finally {
      await _setlists.doc(id).delete();
    }
  });

  check('SL-06', 'Delete a setlist', (tester) async {
    final c = await bootApp(tester);
    const id = 'check-sl-delete';
    const name = 'Check Delete Setlist';
    try {
      await _putSetlist(c, id, name, _songIds.take(1).toList());
      await _openSetlists(tester, name);
      await tester.drag(label(name), const Offset(-500, 0));
      await pause(tester, 800);
      // The app deletes without a confirmation (the snackbar offers Undo).
      await eventually(
        tester,
        () async => (await _setlists.doc(id).get()).exists,
        (exists) => !exists,
        'setlist "$name" removed from Firestore after swiping it away',
        seconds: 8,
        show: (e) => 'document still exists',
      );
      if (found(label(name))) fail('setlist "$name" still shown in the list after deleting');
    } finally {
      await _setlists.doc(id).delete();
    }
  });
}
