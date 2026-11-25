// Songs area: SG-03 .. SG-07, SG-11 .. SG-13.
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/song_form_provider.dart';
import 'package:flowgroove/screens/songs/add_song_screen.dart';
import 'package:flowgroove/screens/songs/components/bpm_selector.dart';
import 'package:flowgroove/screens/songs/components/song_constructor/widgets/edit_section_dialog.dart';
import 'package:flowgroove/screens/songs/components/song_constructor/widgets/section_card.dart';
import 'package:flowgroove/screens/songs/song_editor_screen.dart';
import 'package:flowgroove/widgets/app_dropdown_field.dart';
import 'package:flowgroove/widgets/app_filter_chip.dart';
import 'package:flowgroove/widgets/unified_item/unified_filter_sort_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart' show FocusManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'check.dart';

Finder get _form => find.byType(AddSongScreen);

/// Nth text field of the (embedded) song form: 0 title, 1 artist.
Finder _formField(int n) =>
    find.descendant(of: _form, matching: find.byType(TextFormField)).at(n);

/// Song Page of [title], switched to its Edit tab with the form filled in.
Future<void> _openEditTab(WidgetTester tester, String title) async {
  await openSongPage(tester, title);
  await tapOn(tester, find.text('Edit'), 'Edit tab on the song page');
  await see(tester, _formField(0), 'song form title field');
  await pumpUntil(
    tester,
    () => tester.widget<TextFormField>(_formField(0)).controller?.text == title,
    what: 'song form filled with "$title"',
  );
}

Future<void> _saveChanges(WidgetTester tester) async {
  await see(tester, find.text('Save Changes'), 'Save Changes button');
  // A snackbar from the previous save can sit on top of the button.
  final bar = find.byType(SnackBar);
  if (found(bar) &&
      tester.getRect(bar.first).overlaps(tester.getRect(find.text('Save Changes').first))) {
    checkNote += 'snackbar covered the Save Changes button; waited for it to go. ';
    await pumpUntil(tester, () => !found(bar), what: 'snackbar to disappear');
  }
  await tapOn(tester, find.text('Save Changes'), 'Save Changes button');
}

Future<void> _openSection(WidgetTester tester, String title) async {
  await scrollTo(tester, find.text(title), _form, 'section "$title"');
  await tester.tap(find.text(title).first);
  await pause(tester, 400);
}

List<String> _names(Object? sections) => [
  for (final s in (sections as List? ?? const []))
    (s as Map)['name'] as String,
];

void registerSongsChecks() {
  check('SG-03', 'Add a song (title, artist, BPM, key)', (tester) async {
    await bootApp(tester);
    const id = 'sg03';
    try {
      await openSongsTab(tester);
      await tapOn(tester, find.byTooltip('Add song'), 'add-song button');
      await see(tester, _form, 'add song screen');
      await typeInto(tester, _formField(0), 'Check Added Song', 'title field');
      await typeInto(tester, _formField(1), 'Check Added Artist', 'artist field');
      await tapOn(tester, find.text('Key & BPM'), 'Key & BPM section');
      final grid = find.byType(KeyBpmGrid);
      await see(tester, grid, 'key and BPM grid');
      // Grid fields: 0 original BPM, 1 our BPM; dropdowns 0-1 original, 2-3 ours.
      await typeInto(
        tester,
        find.descendant(of: grid, matching: find.byType(TextFormField)).at(1),
        '96',
        'our BPM field',
      );
      FocusManager.instance.primaryFocus?.unfocus(); // close the keyboard like a user would
      await pause(tester, 600);
      final keyDropdown = find.descendant(of: grid, matching: find.byType(DropdownButton<String>)).at(2);
      await scrollTo(tester, keyDropdown, _form, 'our key root dropdown');
      await tapOn(tester, keyDropdown, 'our key root dropdown');
      await see(tester, find.text('D'), 'key D in the dropdown list');
      await tapOn(tester, find.text('D').last, 'key D in the dropdown');
      await tapOn(tester, find.text('Save Song'), 'Save Song button');

      final songs = await eventually(
        tester,
        () async => (await FirebaseFirestore.instance
                .collection('users/$uid/songs')
                .where('title', isEqualTo: 'Check Added Song')
                .get())
            .docs,
        (docs) => docs.isNotEmpty,
        'saved song "Check Added Song" in Firestore',
      );
      final data = songs.first.data();
      if (data['artist'] != 'Check Added Artist' ||
          data['ourBPM'] != 96 ||
          data['ourKey'] != 'D') {
        fail(
          'expected artist "Check Added Artist", ourBPM 96, ourKey "D"; saved '
          'artist "${data['artist']}", ourBPM ${data['ourBPM']}, ourKey "${data['ourKey']}"',
        );
      }
      await songs.first.reference.delete();
    } finally {
      final stray = await FirebaseFirestore.instance
          .collection('users/$uid/songs')
          .where('title', isEqualTo: 'Check Added Song')
          .get();
      for (final d in stray.docs) {
        await d.reference.delete();
      }
      await songDoc(id).delete();
    }
  });

  check('SG-04', 'Edit a song and save', (tester) async {
    await bootApp(tester);
    const id = 'sg04';
    await putSong(id, 'Check Edit Me', bpm: 90, key: 'E');
    try {
      await _openEditTab(tester, 'Check Edit Me');
      await typeInto(tester, _formField(0), 'Check Edited', 'title field');
      await typeInto(tester, _formField(1), 'Check Edited Artist', 'artist field');
      await _saveChanges(tester);
      final data = await eventually(
        tester,
        () async => (await readSong(id))!,
        (d) => d['title'] == 'Check Edited',
        'edited title saved',
      );
      if (data['artist'] != 'Check Edited Artist') {
        fail(
          'expected artist "Check Edited Artist" after save; saved "${data['artist']}"',
        );
      }
      // The page header must show the new title.
      await see(tester, label('Check Edited'), 'new title on the song page');
    } finally {
      await songDoc(id).delete();
    }
  });

  check('SG-05', 'Delete a song', (tester) async {
    final container = await bootApp(tester);
    const id = 'sg05';
    await putSong(id, 'Check Delete Me');
    try {
      await openSongsTab(tester);
      await typeInto(tester, songSearchField, 'Check Delete Me', 'search field');
      await see(tester, label('Check Delete Me'), 'song to delete');
      await tester.drag(label('Check Delete Me'), const Offset(-500, 0));
      await pause(tester, 600);
      await see(tester, find.text('Delete Song'), 'delete confirmation dialog');
      await tapOn(tester, find.text('Delete'), 'Delete button in the dialog');
      await eventually(
        tester,
        () async => (await songDoc(id).get()).exists,
        (exists) => !exists,
        'song document removed',
      );
      await pause(tester, 600);
      if (found(label('Check Delete Me'))) {
        fail('song document is gone but "Check Delete Me" is still in the list');
      }
      final inProvider = container
          .read(songsProvider)
          .value
          ?.any((s) => s.id == id);
      if (inProvider == true) fail('songsProvider still lists the deleted song');
    } finally {
      await songDoc(id).delete();
    }
  });

  check('SG-06', 'Filter and sort the list', (tester) async {
    await bootApp(tester);
    await openSongsTab(tester);
    final problems = <String>[];
    final alpha = seedSongTitles[0];
    final beta = seedSongTitles[1];
    final gamma = seedSongTitles[2];
    List<String> order() => [
      for (final t in seedSongTitles)
        if (found(label(t))) t,
    ]..sort(
      (a, b) => tester
          .getTopLeft(label(a).first)
          .dy
          .compareTo(tester.getTopLeft(label(b).first).dy),
    );
    String short(Iterable<String> titles) =>
        titles.map((t) => t.split(' ').last).join(', ');
    void expectOrder(String step, List<String> want) {
      final got = order();
      if (got.join('|') != want.join('|')) {
        problems.add('$step: expected [${short(want)}], observed [${short(got)}]');
      }
    }

    Future<void> sortBy(String option) async {
      await tapOn(tester, find.byType(DropdownButton<SortOption>), 'sort dropdown');
      await tapOn(tester, find.text(option).last, 'sort option "$option"');
      await pause(tester, 500);
    }

    Future<void> openFilters() async {
      await tapOn(tester, find.text('Key / BPM'), 'Key / BPM filter button');
      await see(tester, find.text('Filter Options'), 'filter sheet');
    }

    Future<void> closeSheet() async {
      await tester.tapAt(const Offset(8, 60)); // the barrier above the sheet
      await pause(tester, 600);
    }

    Future<void> chooseKeyG() async {
      await openFilters();
      await tapOn(tester, find.widgetWithText(AppFilterChip, 'Major'), 'Major chip');
      await tapOn(tester, find.widgetWithText(AppFilterChip, 'G'), 'key G chip');
      await closeSheet();
    }

    expectOrder('default sort', [alpha, beta, gamma]);
    await sortBy('Date Added');
    expectOrder('sort Date Added (newest first)', [gamma, beta, alpha]);
    await sortBy('Alphabetical');
    expectOrder('sort Alphabetical', [alpha, beta, gamma]);

    await typeInto(tester, songSearchField, 'Beta', 'search field');
    await pause(tester, 500);
    expectOrder('search "Beta"', [beta]);
    await typeInto(tester, songSearchField, '', 'search field');
    await pause(tester, 500);
    expectOrder('search cleared', [alpha, beta, gamma]);

    // Key filter G, removed through the chip's delete icon.
    await chooseKeyG();
    expectOrder('key filter G', [beta]);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(Chip, 'Key: G'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await pause(tester, 600);
    expectOrder('after deleting the "Key: G" chip', [alpha, beta, gamma]);
    if (found(find.text('Key: G'))) {
      problems.add('after deleting the "Key: G" chip the chip is still shown');
    }
    if (found(find.text('Clear'))) {
      await tapOn(tester, find.text('Clear'), 'Clear button'); // reset the stuck state
      await pause(tester, 500);
    }

    // Key filter G, removed through the "All" chip in the sheet.
    await chooseKeyG();
    await openFilters();
    await tapOn(tester, find.widgetWithText(AppFilterChip, 'All').last, 'All chip in the sheet');
    await closeSheet();
    expectOrder('after the "All" key chip', [alpha, beta, gamma]);
    if (found(find.text('Clear'))) {
      await tapOn(tester, find.text('Clear'), 'Clear button');
      await pause(tester, 500);
    }

    // BPM filter: Exact 100 keeps only Beta.
    await openFilters();
    await tapOn(tester, find.byType(TextField).last, 'BPM field in the filter sheet');
    await tapOn(tester, find.text('Exact 100 BPM'), 'Exact 100 BPM menu entry');
    await closeSheet();
    expectOrder('BPM filter 100', [beta]);
    await tapOn(tester, find.text('Clear'), 'Clear button');
    await pause(tester, 600);
    expectOrder('after Clear', [alpha, beta, gamma]);

    // Tag filter from the tag cloud: "learning" is on Beta only.
    await tapOn(tester, find.byWidgetPredicate((w) => w is AppFilterChip && w.label.startsWith('learning')), 'tag chip "learning"');
    await pause(tester, 500);
    expectOrder('tag filter "learning"', [beta]);
    await tapOn(tester, find.widgetWithText(AppFilterChip, 'All'), 'All tag chip');
    await pause(tester, 500);
    expectOrder('after the "All" tag chip', [alpha, beta, gamma]);

    if (problems.isNotEmpty) fail(problems.join('; '));
  });

  check('SG-07', 'Paste a list: review, edit a row, add', (tester) async {
    final container = await bootApp(tester);
    final created = <String>[];
    try {
      await openSongsTab(tester);
      await tapOn(tester, find.byTooltip('Library actions'), 'library actions menu');
      await tapOn(tester, find.text('Paste a list'), 'Paste a list entry');
      await see(tester, find.text('Paste one song per line'), 'paste sheet');
      await typeInto(
        tester,
        find.widgetWithText(TextFormField, 'Paste one song per line'),
        '1. Check Paste One - Paste Artist\n- Check Paste Two',
        'paste text field',
      );
      await tapOn(tester, find.text('Review'), 'Review button');
      await see(tester, find.text('Review 2 songs'), 'review sheet with 2 songs');
      // Edit the first row's title, add a third row.
      final titles = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'Check Paste One',
      );
      await typeInto(tester, titles, 'Check Paste Edited', 'first row title');
      await tapOn(tester, find.text('Add another song'), 'Add another song');
      // Only the new, empty row still shows its "Title" hint.
      await typeInto(
        tester,
        find.widgetWithText(TextFormField, 'Title').last,
        'Check Paste Three',
        'new row title field',
      );
      await see(tester, find.text('Add 3 songs'), 'Add 3 songs button');
      await tapOn(tester, find.text('Add 3 songs'), 'Add 3 songs button');
      final snap = await eventually(
        tester,
        () async => (await FirebaseFirestore.instance
                .collection('users/$uid/songs')
                .where('title', whereIn: ['Check Paste Edited', 'Check Paste Two', 'Check Paste Three'])
                .get())
            .docs,
        (docs) => docs.length == 3,
        'three pasted songs saved',
      );
      created.addAll(snap.map((d) => d.id));
      final byTitle = {for (final d in snap) d['title'] as String: d.data()};
      if (byTitle['Check Paste Edited']?['artist'] != 'Paste Artist') {
        fail('expected edited row to keep artist "Paste Artist"; saved "${byTitle['Check Paste Edited']?['artist']}"');
      }
      final inProvider = container.read(songsProvider).value ?? const [];
      if (!inProvider.any((s) => s.title == 'Check Paste Three')) {
        fail('songsProvider does not list "Check Paste Three" after adding');
      }
      await see(tester, find.text('3 songs added'), 'confirmation snackbar "3 songs added"');
    } finally {
      final stray = await FirebaseFirestore.instance
          .collection('users/$uid/songs')
          .where('title', whereIn: ['Check Paste One', 'Check Paste Edited', 'Check Paste Two', 'Check Paste Three'])
          .get();
      for (final d in stray.docs) {
        await d.reference.delete();
      }
    }
  });

  check('SG-11', 'Song constructor: add, edit, reorder a section', (tester) async {
    await bootApp(tester);
    const id = 'sg11';
    await putSong(id, 'Check Structure Song');
    try {
      await _openEditTab(tester, 'Check Structure Song');
      await _openSection(tester, 'Song Structure');
      for (final name in ['Verse', 'Chorus']) {
        await scrollTo(tester, byKey('song_constructor_add_section'), _form, 'Add Section button');
        await tapOn(tester, byKey('song_constructor_add_section'), 'Add Section button');
        await tapOn(tester, find.byKey(Key('section_picker_parts_$name')), 'picker entry "$name"');
        await pause(tester, 300);
      }
      final cards = find.byType(SectionCard);
      if (cards.evaluate().length != 2) {
        fail('expected 2 section cards after adding Verse and Chorus; observed ${cards.evaluate().length}');
      }
      // Edit the first section: rename Verse to Intro.
      await tester.tap(find.descendant(of: cards.first, matching: find.text('Verse')));
      await see(tester, find.byType(EditSectionDialog), 'Edit Section sheet');
      final name = find.descendant(of: find.byType(EditSectionDialog), matching: find.byType(TextFormField)).first;
      await tester.enterText(name, 'Intro');
      await pause(tester, 200);
      await tapOn(tester, find.descendant(of: find.byType(EditSectionDialog), matching: find.text('Save')), 'Save in the section sheet');
      await pause(tester, 400);
      await _saveChanges(tester);
      final data = await eventually(
        tester,
        () async => (await readSong(id))!,
        (d) => _names(d['sections']).length == 2,
        'two sections saved',
      );
      if (_names(data['sections']).join(',') != 'Intro,Chorus') {
        fail('expected saved sections Intro, Chorus; saved ${_names(data['sections'])}');
      }
      // Reorder in the full-screen song editor: drag Chorus above Intro.
      await menuAction(tester, 'Song editor');
      final editor = find.byType(SongEditorScreen);
      final handles = find.descendant(of: editor, matching: find.byIcon(Icons.drag_handle));
      await see(tester, handles, 'drag handles in the song editor');
      final gesture = await tester.startGesture(tester.getCenter(handles.at(1)));
      await pause(tester, 150);
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, -12));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await gesture.up();
      await pause(tester, 600);
      Finder card(String n) => find.descendant(of: editor, matching: find.descendant(of: find.byType(SectionCard), matching: label(n)));
      final shown = [
        for (final n in ['Intro', 'Chorus'])
          if (found(card(n))) (n, tester.getTopLeft(card(n).first).dy),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      checkNote = 'editor list after drag: ${shown.map((e) => e.$1).join(', ')}';
      await tapOn(tester, find.text('Back').last, 'Back in the song editor');
      await eventually(
        tester,
        () async => _names((await readSong(id))!['sections']).join(','),
        (names) => names == 'Chorus,Intro',
        'expected sections "Chorus,Intro" after dragging Chorus above Intro ($checkNote)',
        seconds: 6,
      );
    } finally {
      await songDoc(id).delete();
    }
  });

  check('SG-12', 'Links editor: add a link', (tester) async {
    await bootApp(tester);
    const id = 'sg12';
    await putSong(id, 'Check Links Song');
    try {
      await _openEditTab(tester, 'Check Links Song');
      await _openSection(tester, 'Links');
      await tapOn(tester, find.text('Add link'), 'Add link button');
      await see(tester, find.text('Add Link'), 'Add Link dialog');
      await tapOn(tester, find.byType(AppDropdownField<String>), 'link type dropdown');
      await tapOn(tester, find.text('Tabs/Chords').last, 'type "Tabs/Chords"');
      await typeInto(
        tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        'https://example.com/check-chords',
        'URL field',
      );
      await tapOn(
        tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
        'Add in the dialog',
      );
      await see(tester, find.byType(RawChip), 'link chip');
      await _saveChanges(tester);
      final data = await eventually(
        tester,
        () async => (await readSong(id))!,
        (d) => (d['links'] as List? ?? const []).isNotEmpty,
        'link saved',
      );
      final link = (data['links'] as List).first as Map;
      if (link['url'] != 'https://example.com/check-chords' || link['type'] == null) {
        fail('expected one saved link to https://example.com/check-chords of type Tabs/Chords; saved $link');
      }
      if (!'${link['type']}'.toLowerCase().contains('tab')) {
        fail('expected link type for "Tabs/Chords" (tabs); saved type "${link['type']}"');
      }
    } finally {
      await songDoc(id).delete();
    }
  });

  check('SG-13', 'Tags: add and remove', (tester) async {
    final container = await bootApp(tester);
    const id = 'sg13';
    await putSong(id, 'Check Tags Song');
    try {
      await _openEditTab(tester, 'Check Tags Song');
      await _openSection(tester, 'Tags');
      // Add a predefined tag by tapping its chip, and a custom one in the dialog.
      await scrollTo(tester, find.widgetWithText(FilterChip, 'easy'), _form, 'tag chip "easy"');
      await tester.tap(find.widgetWithText(FilterChip, 'easy'));
      await pause(tester, 300);
      await tapOn(tester, find.text('Add tag'), 'Add tag chip');
      await see(tester, find.text('Your tags:'), 'tag dialog with the selected tag');
      await tester.enterText(
        find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)),
        'check-tag',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pause(tester, 300);
      await tapOn(
        tester,
        find.descendant(of: find.byType(BottomSheet), matching: find.text('Save')),
        'Save in the tag dialog',
      );
      await pause(tester, 400);
      await _saveChanges(tester);
      final data = await eventually(
        tester,
        () async => (await readSong(id))!,
        (d) => (d['tags'] as List? ?? const []).isNotEmpty,
        'tags saved',
      );
      final tags = List<String>.from(data['tags'] as List)..sort();
      if (tags.join(',') != 'check-tag,easy') {
        fail('expected saved tags check-tag, easy; saved $tags');
      }
      // Remove "easy" by tapping its selected chip.
      await scrollTo(tester, find.widgetWithText(FilterChip, 'easy'), _form, 'tag chip "easy"');
      final wasSelected = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'easy')).selected;
      await tester.tap(find.widgetWithText(FilterChip, 'easy'));
      await pause(tester, 300);
      final nowSelected = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'easy')).selected;
      final before = container.read(songFormStateProvider);
      await _saveChanges(tester);
      await pause(tester, 1500);
      final after = container.read(songFormStateProvider);
      final formInfo =
          'form before save: tags ${before.formData.selectedTags}, unsaved ${before.hasUnsavedChanges}; '
          'after: tags ${after.formData.selectedTags}, unsaved ${after.hasUnsavedChanges}, saving ${after.isSaving}, error ${after.error?.message}';
      await eventually(
        tester,
        () async => List<String>.from((await readSong(id))!['tags'] as List).join(','),
        (t) => t == 'check-tag',
        'expected tags "check-tag" after tapping the selected "easy" chip (chip selected before $wasSelected, after $nowSelected; $formInfo)',
        seconds: 6,
      );
    } finally {
      await songDoc(id).delete();
    }
  });
}
