// Recorder and lab (RC-01 .. RC-04) and MIDI (MD-01 .. MD-03).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/recorder_screen.dart';
import 'package:flowgroove/screens/songs/song_lab_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'check.dart';

CollectionReference<Map<String, dynamic>> get _inbox =>
    FirebaseFirestore.instance.collection('users/$uid/songs/_inbox/labEntries');

CollectionReference<Map<String, dynamic>> _labOf(String songId) =>
    FirebaseFirestore.instance.collection('users/$uid/songs/$songId/labEntries');

Future<void> _openRecorder(WidgetTester tester) async {
  unawaited(appRouter.push('/main/recorder'));
  await see(tester, find.byType(RecorderScreen), 'recorder screen');
}

/// A recording in the idea inbox that plays: it reuses the seeded recording's audio.
Future<void> _putInboxRecording(String id, String title) async {
  final seed = (await _labOf(seedSongId).doc(seedEntryId).get()).data()!;
  final now = DateTime.now().toIso8601String();
  await _inbox.doc(id).set({
    'id': id,
    'songId': '_inbox',
    'type': 'recording',
    'title': title,
    'authorId': uid,
    'visibility': 'private',
    'tags': <String>[],
    'createdAt': now,
    'updatedAt': now,
    'attachmentIds': seed['attachmentIds'],
    'peaks': <num>[],
    'peaksRms': false,
  });
}

void registerRecorderChecks() {
  check('RC-01', 'Record 5 s, stop, entry appears', (tester) async {
    await bootApp(tester);
    const title = 'Check Take';
    try {
      await _openRecorder(tester);
      await tapOn(tester, find.text('Record').first, 'Record button');
      await see(tester, find.text('Audio idea'), 'recording sheet');
      final sheet = find.byType(BottomSheet);
      await tapOn(tester, find.descendant(of: sheet, matching: find.text('Record')), 'Record in the sheet');
      final stop = find.descendant(of: sheet, matching: find.text('Stop'));
      await expectSeen(tester, stop, 'expected the Stop button after Record (microphone not granted or no input device?)', seconds: 15);
      await pause(tester, 5000);
      await tapOn(tester, stop, 'Stop');
      await typeInto(tester, find.descendant(of: sheet, matching: find.byType(TextFormField)).first, title, 'title field');
      final save = find.descendant(of: sheet, matching: find.text('Save'));
      await expectSeen(tester, save, 'expected a Save button after stopping');
      await tapOn(tester, save, 'Save');
      final docs = await eventually(
        tester,
        () async => (await _inbox.where('title', isEqualTo: title).get()).docs,
        (d) => d.isNotEmpty,
        'recording "$title" saved to the idea inbox',
        seconds: 30,
        show: (d) => 'none',
      );
      final data = docs.first.data();
      final urls = (data['attachmentIds'] as List?) ?? const [];
      if (urls.isEmpty) fail('expected the saved entry to carry an audio file; attachmentIds empty');
      await expectSeen(tester, label(title), 'expected the recording "$title" in the Recordings list');
    } finally {
      for (final d in (await _inbox.where('title', isEqualTo: title).get()).docs) {
        await d.reference.delete();
      }
    }
  });

  check('RC-02', 'Play the recording', (tester) async {
    await bootApp(tester);
    const id = 'check-rc02';
    const title = 'Check Playable';
    await _putInboxRecording(id, title);
    try {
      await _openRecorder(tester);
      await see(tester, find.byTooltip('Play $title'), 'play button for "$title"');
      await tapOn(tester, find.byTooltip('Play $title'), 'play button');
      await expectSeen(tester, find.byTooltip('Pause $title'), 'expected the play button to become Pause while playing', seconds: 10);
      await pause(tester, 1500);
      if (!found(find.byTooltip('Pause $title'))) {
        fail('expected playback to continue after 1.5 s; the button is back to Play (clip is 1 bar+); on screen: ${onScreen()}');
      }
      await tapOn(tester, find.byTooltip('Pause $title'), 'pause button');
      await expectSeen(tester, find.byTooltip('Play $title'), 'expected Play again after pausing');
    } finally {
      await _inbox.doc(id).delete();
    }
  });

  check('RC-03', 'Link a recording to a song', (tester) async {
    await bootApp(tester);
    const id = 'check-rc03';
    const title = 'Check Linkable';
    await _putInboxRecording(id, title);
    try {
      await _openRecorder(tester);
      await tapOn(tester, find.byTooltip('Menu for $title'), 'card menu');
      await tapOn(tester, find.text('Link to song…'), 'Link to song');
      await see(tester, find.text('Link recording to song'), 'song picker');
      await tapOn(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Check Song Beta')), 'song "Check Song Beta"');
      await eventually(
        tester,
        () async => (await _labOf('check-song-2').where('title', isEqualTo: title).get()).docs,
        (d) => d.isNotEmpty,
        'recording "$title" under Check Song Beta',
        show: (d) => 'none',
      );
      final left = (await _inbox.doc(id).get()).exists;
      if (left) fail('expected the recording to leave the idea inbox once linked; bands inbox still holds $id');
    } finally {
      await _inbox.doc(id).delete();
      for (final d in (await _labOf('check-song-2').where('title', isEqualTo: title).get()).docs) {
        await d.reference.delete();
      }
    }
  });

  check('RC-04', 'Song lab tasks list opens and a task can be ticked', (tester) async {
    await bootApp(tester);
    const title = 'Check Task One';
    final tasks = FirebaseFirestore.instance.collection('users/$uid/songs/$seedSongId/tasks');
    try {
      await openSongPage(tester, seedSongTitles[0]);
      await tapOn(tester, find.text('Lab'), 'Lab tab');
      await see(tester, find.byType(SongLabScreen), 'song lab');
      await tapOn(tester, find.text('Tasks'), 'Tasks segment');
      await tapOn(tester, find.text('Add task'), 'Add task');
      await see(tester, find.text('New task'), 'new task sheet');
      await typeInto(tester, find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextFormField)).first, title, 'task field');
      await tapOn(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Add')), 'Add');
      await see(tester, label(title), 'task "$title" in the list');
      final saved = await eventually(
        tester,
        () async => (await tasks.where('title', isEqualTo: title).get()).docs,
        (d) => d.isNotEmpty,
        'task saved',
        show: (d) => 'none',
      );
      if (saved.first.data()['status'] != 'todo') fail('expected a new task to be "todo"; saved "${saved.first.data()['status']}"');
      final chip = find.widgetWithText(ActionChip, 'todo');
      for (final next in ['doing', 'done']) {
        await tapOn(tester, find.widgetWithText(ActionChip, next == 'doing' ? 'todo' : 'doing'), 'status chip');
        await eventually(
          tester,
          () async => (await tasks.doc(saved.first.id).get()).data()?['status'],
          (s) => s == next,
          'task status "$next"',
          show: (s) => '"$s"',
        );
      }
      if (found(chip)) fail('a "todo" chip is still shown after the task was done');
      await see(tester, find.widgetWithText(ActionChip, 'done'), 'a "done" chip');
    } finally {
      for (final d in (await tasks.where('title', isEqualTo: title).get()).docs) {
        await d.reference.delete();
      }
    }
  });

  check('MD-01', 'Import a MIDI file', (tester) async {
    throw CheckSkip('the import opens the native file picker (FilePicker.pickFile), which a widget test cannot drive; no way to hand it a file');
  });

  check('MD-02', 'MIDI song panel plays / stops', (tester) async {
    throw CheckSkip(
      'needs a song with a MIDI backing track, which only the native import (MD-01) creates; seeding one means '
      'generating an SMF, uploading it and building the midiSong metadata. The panel is also !kIsWeb. Not done in this batch',
    );
  });

  check('MD-03', 'Drum grid editor: toggle a step, save', (tester) async {
    throw CheckSkip('the drum grid editor is reached only from a MIDI drum track (BackingSheet), so it depends on a MIDI song as in MD-02');
  });
}
