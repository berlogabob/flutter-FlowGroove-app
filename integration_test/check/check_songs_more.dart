// Songs area, batch 2: SG-06b, SG-08, SG-09, SG-10 and SL-04.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowgroove/models/event_kit.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/setlists/setlist_view_screen.dart';
import 'package:flowgroove/screens/setlists/setlists_list_screen.dart';
import 'package:flowgroove/screens/songs/song_duplicates_screen.dart';
import 'package:flowgroove/screens/songs/song_editor_screen.dart';
import 'package:flowgroove/services/export/pdf_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'check.dart';

Future<void> _libraryAction(WidgetTester tester, String entry) async {
  await tapOn(tester, find.byTooltip('Library actions'), 'library actions menu');
  await tapOn(tester, find.text(entry), 'library action "$entry"');
}

List<String> _names(Object? sections) => [
  for (final s in (sections as List? ?? const [])) (s as Map)['name'] as String,
];

void registerSongsMoreChecks() {
  check('SG-06b', 'Tempo filter can be removed by its chip', (tester) async {
    await bootApp(tester);
    await openSongsTab(tester);
    List<String> shown() => [for (final t in seedSongTitles) if (found(label(t))) t.split(' ').last];
    Future<void> clear() async {
      if (found(find.text('Clear'))) {
        await tapOn(tester, find.text('Clear'), 'Clear button');
        await pause(tester, 500);
      }
    }

    try {
      await tapOn(tester, find.text('Key / BPM'), 'Key / BPM filter button');
      await see(tester, find.text('Filter Options'), 'filter sheet');
      await tapOn(tester, find.byType(TextField).last, 'BPM field in the filter sheet');
      await tapOn(tester, find.text('Exact 100 BPM'), 'Exact 100 BPM menu entry');
      await tester.tapAt(const Offset(8, 60));
      await pause(tester, 600);
      if (shown().join(',') != 'Beta') fail('BPM filter 100: expected [Beta]; observed ${shown()}');
      final chip = find.byWidgetPredicate(
        (w) => w is Chip && w.label is Text && ((w.label as Text).data ?? '').startsWith('BPM'),
      );
      await see(tester, chip, 'tempo filter chip');
      final chipText = ((tester.widget<Chip>(chip).label) as Text).data;
      await tester.tap(find.descendant(of: chip, matching: find.byIcon(Icons.close)));
      await pause(tester, 600);
      final problems = <String>[];
      if (shown().join(',') != 'Alpha,Beta,Gamma') {
        problems.add('after deleting the "$chipText" chip: expected [Alpha, Beta, Gamma], observed ${shown()}');
      }
      if (found(chip)) problems.add('after deleting the "$chipText" chip the chip is still shown');
      if (problems.isNotEmpty) fail(problems.join('; '));
    } finally {
      await clear();
    }
  });

  check('SG-08', 'Import lyrics', (tester) async {
    await bootApp(tester);
    const id = 'sg08';
    await putSong(id, 'Check Lyrics Target');
    try {
      await openSongPage(tester, 'Check Lyrics Target');
      await menuAction(tester, 'Song editor');
      await see(tester, find.byType(SongEditorScreen), 'song editor');
      await tapOn(tester, find.text('Menu').last, 'Menu button of the song editor');
      await tapOn(tester, find.text('Import lyrics & chords'), 'menu row "Import lyrics & chords"');
      await see(tester, find.text('Paste ChordPro. A full chart with {title}, {key}, {tempo} and {start_of_verse: …} blocks fills the whole song; plain lyrics with [Verse 1] or "Chorus:" just split into sections.'), 'import sheet');
      await typeInto(
        tester,
        find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)),
        '{title: Check Lyrics Song}\n{artist: Lyrics Artist}\n{key: Dm}\n{tempo: 123}\n\n'
            '{start_of_verse: Verse 1}\n[Dm]He left no time to [Gm]regret\n{end_of_verse}\n'
            '{start_of_chorus: Chorus}\n[Bb]Sing it [C]loud\n{end_of_chorus}',
        'import text field',
      );
      await see(tester, find.textContaining('Preview — 2 section(s)'), 'preview of 2 sections');
      await see(tester, find.textContaining('Check Lyrics Song'), 'detected song details');
      await scrollTo(tester, find.text('Import 2'), find.byType(BottomSheet), 'Import 2 button');
      await tapOn(tester, find.text('Import 2'), 'Import 2 button');
      await pause(tester, 800);
      if (found(find.textContaining('No sections yet'))) fail('expected sections in the editor after Import 2; it still says "No sections yet"');
      await tapOn(tester, find.text('Back').last, 'Back in the song editor');
      final data = await eventually(
        tester,
        () async => (await readSong(id))!,
        (d) => _names(d['sections']).isNotEmpty,
        'imported sections saved',
        seconds: 8,
        show: (d) => 'saved title "${d['title']}", sections ${_names(d['sections'])}',
      );
      final problems = <String>[];
      if (_names(data['sections']).length != 2) problems.add('expected 2 saved sections; saved ${_names(data['sections'])}');
      final chart = '${((data['sections'] as List).first as Map)['chordChart']}';
      if (!chart.contains('He left no time to')) problems.add('expected the first section chart to hold the pasted lyrics; saved "$chart"');
      if (data['title'] != 'Check Lyrics Song') problems.add('expected title "Check Lyrics Song" from {title}; saved "${data['title']}"');
      if (data['artist'] != 'Lyrics Artist') problems.add('expected artist "Lyrics Artist" from {artist}; saved "${data['artist']}"');
      if (data['ourKey'] != 'Dm') problems.add('expected ourKey "Dm" from {key}; saved "${data['ourKey']}"');
      if (data['ourBPM'] != 123) problems.add('expected ourBPM 123 from {tempo}; saved ${data['ourBPM']}');
      if (problems.isNotEmpty) fail(problems.join('; '));
    } finally {
      await songDoc(id).delete();
    }
  });

  check('SG-09', 'Export song / CSV', (tester) async {
    final c = await bootApp(tester);
    await openSongsTab(tester);
    final count = c.read(songsProvider).value?.length ?? 0;
    await _libraryAction(tester, 'Export to CSV');
    await see(tester, find.text('Export Songs'), 'export dialog');
    await see(tester, find.text('Export $count song(s) to CSV file:'), 'export dialog count for $count songs');
    await see(tester, find.text('Save to Device'), 'Save to Device button');
    await see(tester, find.text('Share'), 'Share button');
    await tapOn(tester, find.text('Copy as JSON'), 'Copy as JSON button');
    final copied = find.text('$count song(s) copied as JSON');
    try {
      await see(tester, copied, 'snackbar "$count song(s) copied as JSON"', seconds: 6);
    } on TimeoutException {
      if (!kIsWeb) rethrow;
      // Chrome refuses clipboard writes without user activation and page focus.
      checkNote = 'web: Chrome refused the clipboard write (PlatformException copy_fail) under automation, so no snackbar; test limitation';
      await tapOn(tester, find.text('Cancel'), 'Cancel in the export dialog');
      return;
    }
    String? clip;
    try {
      clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {}
    if (clip == null) {
      checkNote = 'clipboard unreadable here; only the dialog, count and snackbar were checked; Save to Device and Share are system dialogs, not driven';
    } else {
      final missing = [for (final t in seedSongTitles) if (!clip.contains(t)) t];
      if (missing.isNotEmpty) fail('expected the copied JSON to contain every seeded title; missing $missing (${clip.length} chars)');
      checkNote = 'Save to Device and Share are system dialogs, not driven';
    }
    await tapOn(tester, find.text('Cancel'), 'Cancel in the export dialog');
  });

  check('SG-10', 'Duplicates screen merges two songs', (tester) async {
    final c = await bootApp(tester);
    await putSong('sg10-a', 'Zebra Crossing Waltz', artist: 'Zed Quartet', key: 'C', bpm: 90);
    await putSong('sg10-b', 'Zebra Crossing Waltz', artist: 'Zed Quartet', key: 'C', bpm: 90);
    try {
      await openSongsTab(tester);
      await eventually(
        tester,
        () async => c.read(songsProvider).value?.where((s) => s.title == 'Zebra Crossing Waltz').length ?? 0,
        (n) => n == 2,
        'both duplicate songs loaded in the app',
      );
      await _libraryAction(tester, 'Find duplicates');
      await see(tester, find.byType(SongDuplicatesScreen), 'duplicates screen');
      final entry = find.textContaining('• Zebra Crossing Waltz');
      await expectSeen(tester, entry, 'expected a duplicate cluster listing "Zebra Crossing Waltz"');
      // The seeded "Check Song ..." titles also form a cluster: use the card of the duplicates under test.
      final card = find.ancestor(of: entry.first, matching: find.byType(Card));
      await tapOn(tester, find.descendant(of: card, matching: find.widgetWithText(FilledButton, 'Merge…')), 'Merge… button of the Zebra cluster');
      await tapOn(tester, find.widgetWithText(FilledButton, 'Merge'), 'Merge button on the merge screen');
      final left = await eventually(
        tester,
        () async => (await FirebaseFirestore.instance.collection('users/$uid/songs').where('title', isEqualTo: 'Zebra Crossing Waltz').get()).docs.length,
        (n) => n == 1,
        'expected 1 song left 20 s after Merge (on screen: ${onScreen()})',
        seconds: 20,
      );
      if (left != 1) fail('expected 1 song left after the merge; found $left');
      await expectSeen(tester, find.text('Merged 2 songs into "Zebra Crossing Waltz".'), 'expected the snackbar "Merged 2 songs into ..." after the merge');
      await pause(tester, 600);
      if (found(entry)) fail('merged songs still listed as duplicates');
    } finally {
      for (final id in ['sg10-a', 'sg10-b']) {
        await songDoc(id).delete();
      }
    }
  });

  check('SL-04', 'Export (as is / whose copy)', (tester) async {
    final c = await bootApp(tester);
    const id = 'check-sl-export';
    const name = 'Check Export Setlist';
    final now = DateTime.now();
    final setlist = Setlist(
      id: id,
      bandId: '',
      name: name,
      createdAt: now,
      updatedAt: now,
      songIds: const ['check-song-1', 'check-song-2'],
      items: const [
        SetlistItem(id: 'e1', songId: 'check-song-1', performerIds: ['p1']),
        SetlistItem(id: 'e2', songId: 'check-song-2'),
      ],
      eventKit: const EventKit(people: [EventPerson(id: 'p1', name: 'Check Drummer', role: 'drums')]),
    );
    // saveSetlist drops the event kit on purpose, so write the document whole.
    await FirebaseFirestore.instance.doc('users/$uid/setlists/$id').set(setlist.toJson());
    try {
      appRouter.go('/main/setlists');
      await see(tester, find.byType(SetlistsListScreen), 'setlists screen');
      await tapOn(tester, label(name), 'setlist "$name" card');
      await see(tester, find.byType(SetlistViewScreen), 'setlist view');
      await menuAction(tester, 'Export to PDF');
      await see(tester, find.text('As is'), 'export layout "As is"');
      await pause(tester, 800); // the sheet slides in; a tap during the slide lands on the page behind it
      for (final t in ['Compact', 'SetlistPack', 'Cheat sheet', 'One musician']) {
        if (!found(find.text(t))) fail('expected export layout "$t" in the sheet; on screen: ${onScreen()}');
      }
      // The last row sits half under the sheet's bottom edge: scroll the sheet like a user would.
      final sheetRect = tester.getRect(find.byType(BottomSheet));
      for (var i = 0; i < 5 && !sheetRect.contains(tester.getCenter(find.text('One musician'))); i++) {
        await tester.drag(find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first, const Offset(0, -120));
        await pause(tester, 300);
      }
      await tapOn(tester, find.text('One musician'), 'layout "One musician"');
      await see(tester, find.text('Whose copy?'), 'whose copy sheet');
      await see(tester, find.text('Check Drummer'), 'performer "Check Drummer"');
      if (!found(find.text('#1'))) fail('expected the performer row to list song #1; on screen: ${onScreen()}');
      await tester.tapAt(const Offset(8, 60)); // dismiss without handing the PDF to the system
      await pause(tester, 600);
      // The documents themselves build (the share step is a system dialog).
      final songs = <Song>[for (final s in c.read(songsProvider).value ?? const <Song>[]) if (setlist.songIds.contains(s.id)) s];
      for (final (layout, performer) in [(SetlistPdfLayout.detailed, null), (SetlistPdfLayout.performer, 'p1')]) {
        final bytes = await PdfService.buildSetlistBytes(setlist, songs, layout: layout, performerId: performer);
        if (bytes.length < 500 || String.fromCharCodes(bytes.take(4)) != '%PDF') {
          fail('expected a PDF document for layout ${layout.name}; got ${bytes.length} bytes');
        }
      }
      checkNote = 'sheet and PDF build checked; the share/save step is a system dialog, not driven';
    } finally {
      await FirebaseFirestore.instance.doc('users/$uid/setlists/$id').delete();
    }
  });
}
