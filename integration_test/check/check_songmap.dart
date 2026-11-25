// Song Map: SM-01, SM-03, SM-05 .. SM-08, SM-10 .. SM-17.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'check.dart';
import 'web_probe_stub.dart' if (dart.library.js_interop) 'web_probe_web.dart';

CollectionReference<Map<String, dynamic>> get _entries => FirebaseFirestore
    .instance
    .collection('users/$uid/songs/$seedSongId/labEntries');

/// A private copy of the seeded recording, so edits never touch the seed.
Future<void> _copySeedEntry(
  String id, {
  Map<String, dynamic> Function(Map<String, dynamic>)? edit,
}) async {
  final seed = (await _entries.doc(seedEntryId).get()).data()!;
  final copy = {...seed, 'id': id};
  await _entries.doc(id).set(edit == null ? copy : edit(copy));
}

Future<SongLabEntry> _read(String id) async =>
    SongLabEntry.fromJson((await _entries.doc(id).get()).data()!);

String _show(List<AudioRegion> regions) => regions
    .map(
      (r) =>
          '${r.name}${r.section != null ? '/${r.section}' : ''}[${r.startMs}..${r.endMs}]',
    )
    .join(' ');

Future<void> _openMap(WidgetTester tester, String entryId) async {
  final entry = await _read(entryId);
  unawaited(
    appRouter.push('/main/practice-regions/$entryId', extra: {'entry': entry}),
  );
  await see(tester, find.byType(PracticeRegionsScreen), 'Song Map screen');
  await pumpUntil(
    tester,
    () =>
        found(byKey('play')) &&
        tester.widget<FilledButton>(byKey('play')).onPressed != null,
    what: 'audio loaded (play enabled)',
  );
  await pause(tester, 500);
}

({int pos, bool playing}) _player(WidgetTester tester) {
  final t = tester.widget<SongMapTimeline>(byKey('song-map-zoom'));
  return (pos: t.positionMs ?? 0, playing: t.playing);
}

/// Seeks by tapping the overview waveform at [ms] of the 16 s recording.
Future<void> _seek(WidgetTester tester, int ms, {int total = 16000}) async {
  final box = tester.getRect(byKey('song-map-overview'));
  await tester.tapAt(Offset(box.left + box.width * ms / total, box.top + 40));
  await pause(tester, 600);
}

Future<void> _moreMenu(WidgetTester tester, String item) async {
  await tapOn(tester, find.byTooltip('More'), 'More menu in the Song Map bar');
  await tapOn(tester, find.text(item), 'More menu row "$item"');
}

/// Pad ids shown, with the text on each pad.
List<String> _pads(WidgetTester tester) {
  final pads = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        k.value.startsWith('song-map-pad-') &&
        !k.value.startsWith('song-map-pad-badge-');
  });
  return [
    for (final e in pads.evaluate())
      '${(e.widget.key! as ValueKey<String>).value.substring(13)}='
          '${find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate().map((t) => (t.widget as Text).data).whereType<String>().join('|')}',
  ];
}

Future<void> _tapKey(WidgetTester tester, String key) =>
    tapOn(tester, byKey('song-map-key-$key'), 'bank key $key');

/// Samples where the audio really is while a part loops. On web that is the `<audio>` element's own
/// `currentTime` (captured by [installAudioProbe]); elsewhere, or before an element exists, the
/// position the app shows. The app position alone can pass while the sound is somewhere else.
class RealAudioWatch {
  final samples = <({int at, int ms, bool paused, bool real})>[];

  /// Takes one sample [elapsed] ms into a pass; [appMs] is the app's own position.
  void sample(int elapsed, int appMs) {
    final r = audioElementNow();
    samples.add((
      at: elapsed,
      ms: r == null ? appMs : (r.time * 1000).round(),
      paused: r?.paused ?? false,
      real: r != null,
    ));
  }

  /// Throws unless every sample after [settleMs] lies in [start, end] (+- [slack]) and the audio
  /// wrapped at least [wraps] times. Returns a summary.
  String verify(
    String label,
    int start,
    int end, {
    int settleMs = 1000,
    int slack = 500,
    int wraps = 2,
  }) {
    final span = end - start;
    final settled = samples.where((s) => s.at >= settleMs).toList();
    var wrapped = 0;
    for (var i = 1; i < settled.length; i++) {
      if (settled[i].ms < settled[i - 1].ms - span ~/ 2) wrapped++;
    }
    final ms = samples.map((s) => s.ms);
    final summary =
        '$label [$start..$end] ${samples.first.real ? 'REAL audio' : 'app position'} '
        'observed ${ms.reduce((a, b) => a < b ? a : b)}..${ms.reduce((a, b) => a > b ? a : b)} ms, $wrapped wraps '
        '(first samples ${samples.take(6).map((s) => '+${s.at}:${s.ms}').join(' ')})';
    String tail() {
      final log = audioElementLog();
      return log.isEmpty
          ? ''
          : '\naudio element log (last 60):\n${log.skip(log.length > 60 ? log.length - 60 : 0).join('\n')}';
    }

    final out = settled.where(
      (s) => s.ms < start - slack || s.ms > end + slack,
    );
    if (out.isNotEmpty) {
      throw TestFailure(
        'audio left the part: ${out.first.ms} ms at +${out.first.at} ms; $summary${tail()}',
      );
    }
    final paused = settled.where((s) => s.real && s.paused);
    if (paused.isNotEmpty) {
      throw TestFailure(
        'audio element paused at +${paused.first.at} ms while playing; $summary${tail()}',
      );
    }
    if (wrapped < wraps)
      throw TestFailure(
        'looped $wrapped times, need $wraps; $summary${tail()}',
      );
    return summary;
  }
}

String _tailLog() {
  final log = audioElementLog();
  return log.isEmpty
      ? ''
      : '\naudio element log (last 40):\n${log.skip(log.length > 40 ? log.length - 40 : 0).join('\n')}';
}

Future<void> _sampleLoop(
  WidgetTester tester,
  RealAudioWatch watch,
  int ms,
) async {
  final clock = Stopwatch()..start();
  while (clock.elapsedMilliseconds < ms) {
    await pause(tester, 100);
    watch.sample(clock.elapsedMilliseconds, _player(tester).pos);
  }
}

void registerSongMapChecks() {
  check('SM-01', 'Open Song Map of a song with audio', (tester) async {
    await bootApp(tester);
    await openSongPage(tester, seedSongTitles[0]);
    await tapOn(tester, find.text('Lab'), 'Lab tab on the song page');
    await tapOn(
      tester,
      find.textContaining('Check recording'),
      'recording entry',
    );
    await see(tester, find.byType(PracticeRegionsScreen), 'Song Map screen');
    await pumpUntil(
      tester,
      () =>
          found(byKey('play')) &&
          tester.widget<FilledButton>(byKey('play')).onPressed != null,
      what: 'audio loaded (play enabled)',
    );
    await pause(tester, 500);
    final seen = _pads(tester);
    for (final name in ['Verse', 'Chorus']) {
      if (!seen.any(
        (p) =>
            p.endsWith('=$name') ||
            p.contains('|$name') ||
            p.contains('=$name|'),
      )) {
        fail('expected a pad named "$name"; pads shown: $seen');
      }
    }
    if (!found(find.text('120 BPM'))) fail('expected the tempo chip "120 BPM"');
  });

  check('SM-03', 'Play / Pause follows the player', (tester) async {
    await bootApp(tester);
    await _openMap(tester, seedEntryId);
    try {
      if (_player(tester).playing) fail('player already playing before Play');
      await tester.tap(byKey('play'));
      await pumpUntil(
        tester,
        () => _player(tester).playing,
        what: 'Song Map playing',
      );
      final p0 = _player(tester).pos;
      // Real time, not tester.pump(duration): on web the binding's pump does not wait, and the player runs on the wall clock.
      await pause(tester, 1500);
      final p1 = _player(tester).pos;
      if (!_player(tester).playing || p1 <= p0 + 500) {
        fail(
          'expected the position to advance ~1500 ms while playing; $p0 -> $p1 ms, playing ${_player(tester).playing}',
        );
      }
      await tester.tap(byKey('play'));
      await pumpUntil(
        tester,
        () => !_player(tester).playing,
        what: 'Song Map paused',
      );
      final q0 = _player(tester).pos;
      await pause(tester, 1000);
      final q1 = _player(tester).pos;
      if ((q1 - q0).abs() > 100)
        fail('position kept moving while paused: $q0 -> $q1 ms');
    } finally {
      if (_player(tester).playing) await tester.tap(byKey('play'));
    }
  });

  check('SM-05', 'Chop splits at the play position; names follow badges', (
    tester,
  ) async {
    await bootApp(tester);
    const id = 'check-map-chop';
    try {
      await _copySeedEntry(id);
      await _openMap(tester, id);
      await _seek(tester, 6000);
      final before = (await _read(id)).regions;
      await _tapKey(tester, 'Chop');
      final entry = await eventually(
        tester,
        () => _read(id),
        (e) => e.regions.length == before.length + 1,
        'chop saved a new region',
        seconds: 8,
        show: (e) => 'regions ${_show(e.regions)}',
      );
      final cuts = entry.regions.map((r) => r.endMs).toList();
      if (!cuts.contains(6000)) {
        fail(
          'expected a cut at 6000 ms (play position); regions ${_show(entry.regions)}',
        );
      }
      // Auto names follow the badge letter shown on the pads.
      await pause(tester, 600);
      final pads = _pads(tester);
      for (final r in entry.regions) {
        final m = RegExp(r'^Part ([A-Z]+) \d+$')
            .firstMatch(r.section ?? r.name);
        if (m == null) continue;
        final badge = find.descendant(
          of: byKey('song-map-pad-badge-${r.id}'),
          matching: find.byType(Text),
        );
        if (!found(badge)) continue;
        final letter = (badge.evaluate().first.widget as Text).data;
        if (letter != m.group(1)) {
          fail(
            'section "${r.section ?? r.name}" shows badge "$letter"; pads $pads',
          );
        }
      }
      checkNote = 'regions ${_show(entry.regions)}; pads $pads';
    } finally {
      await _entries.doc(id).delete();
    }
  });

  check('SM-06', 'Merge selected pads', (tester) async {
    await bootApp(tester);
    const id = 'check-map-merge';
    try {
      await _copySeedEntry(id);
      await _openMap(tester, id);
      await _tapKey(tester, 'Range');
      await tapOn(tester, byKey('song-map-pad-part-v1'), 'Verse pad');
      await tapOn(tester, byKey('song-map-pad-part-c1'), 'Chorus pad');
      await _tapKey(tester, 'Shift');
      await _tapKey(tester, 'Chop');
      await see(tester, find.text('Merged 2 pads'), 'snackbar "Merged 2 pads"');
      final entry = await eventually(
        tester,
        () => _read(id),
        (e) => e.regions.map((r) => r.section).toSet().length == 1,
        'two sections merged into one',
        seconds: 8,
        show: (e) => 'regions ${_show(e.regions)}',
      );
      checkNote = 'regions ${_show(entry.regions)}';
    } finally {
      await _entries.doc(id).delete();
    }
  });

  check('SM-07', 'Rename a section', (tester) async {
    await bootApp(tester);
    const id = 'check-map-rename';
    try {
      await _copySeedEntry(id);
      await _openMap(tester, id);
      await tester.longPress(byKey('song-map-pad-part-v1'));
      await pause(tester, 500);
      await see(tester, find.text('Rename section'), 'Rename section sheet');
      await typeInto(
        tester,
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'Bridge',
        'name field',
      );
      await tapOn(tester, find.text('Save'), 'Save in the sheet');
      final entry = await eventually(
        tester,
        () => _read(id),
        (e) => e.regions.first.section == 'Bridge',
        'first section renamed to "Bridge"',
        seconds: 8,
        show: (e) => 'regions ${_show(e.regions)}',
      );
      await see(tester, label('Bridge'), 'pad named "Bridge"');
      checkNote = 'regions ${_show(entry.regions)}';
    } finally {
      await _entries.doc(id).delete();
    }
  });

  check('SM-08', 'Tempo sheet: Stretch / Keep; song BPM untouched', (
    tester,
  ) async {
    await bootApp(tester);
    const id = 'check-map-tempo';
    final prefs = await SharedPreferences.getInstance();
    Future<void> clearPrefs() async {
      for (final k in prefs.getKeys().where(
        (k) => k.startsWith('practice_tempo_stretch'),
      )) {
        await prefs.remove(k);
      }
    }

    try {
      await clearPrefs();
      await _copySeedEntry(
        id,
        edit: (d) => {
          ...d,
          'grid': {...(d['grid'] as Map<String, dynamic>), 'bpm': 119.6},
        },
      );
      final songBefore = (await readSong(seedSongId))!['ourBPM'];
      await _openMap(tester, id);
      await see(
        tester,
        find.text('Stretch to 120'),
        'tempo banner "Stretch to 120"',
      );
      await see(tester, find.text('Keep'), 'Keep button');
      await tapOn(tester, find.text('Stretch to 120'), 'Stretch button');
      await pause(tester, 600);
      if (found(find.text('Keep')))
        fail('banner still shown after choosing Stretch');
      await see(
        tester,
        find.text('120 BPM'),
        'tempo chip "120 BPM" after Stretch',
      );
      await tapOn(tester, byKey('tempo-chip'), 'tempo chip');
      await see(tester, byKey('tempo-value'), 'tempo sheet');
      final shown = (tester.widget<Text>(byKey('tempo-value'))).data;
      if (shown != '120') fail('tempo sheet expected 120; observed $shown');
      await tapOn(tester, find.text('+1'), '+1 in the tempo sheet');
      await tapOn(tester, byKey('tempo-save'), 'Save in the tempo sheet');
      final entry = await eventually(
        tester,
        () => _read(id),
        (e) => e.grid?.bpm == 121,
        'grid BPM 121 saved',
        seconds: 8,
        show: (e) => 'grid bpm ${e.grid?.bpm}',
      );
      final songAfter = (await readSong(seedSongId))!['ourBPM'];
      if (songAfter != songBefore)
        fail(
          'song BPM changed from $songBefore to $songAfter by editing the Song Map grid',
        );
      checkNote = 'grid ${entry.grid?.bpm}, song BPM $songBefore -> $songAfter';
    } finally {
      await clearPrefs();
      await _entries.doc(id).delete();
    }
  });

  check('SM-10', 'Save map; reopen shows the same map', (tester) async {
    await bootApp(tester);
    const id = 'check-map-reopen';
    try {
      await _copySeedEntry(id);
      await _openMap(tester, id);
      await _seek(tester, 6000);
      await _tapKey(tester, 'Chop');
      await eventually(
        tester,
        () => _read(id),
        (e) => e.regions.length == 5,
        'chop saved',
        seconds: 8,
        show: (e) => 'regions ${_show(e.regions)}',
      );
      await pause(tester, 600);
      final before = _pads(tester);
      appRouter.pop();
      await pause(tester, 800);
      await _openMap(tester, id);
      final after = _pads(tester);
      if (before.join(';') != after.join(';')) {
        fail('map differs after reopening; before $before; after $after');
      }
    } finally {
      await _entries.doc(id).delete();
    }
  });

  check('SM-11', 'Notes: add a note marker', (tester) async {
    await bootApp(tester);
    const id = 'check-map-note';
    try {
      await _copySeedEntry(id);
      await _openMap(tester, id);
      await _seek(tester, 6000);
      await _moreMenu(tester, 'Add note at playhead');
      await see(tester, find.textContaining('Note at'), 'note dialog');
      await typeInto(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'check note text',
        'note field',
      );
      await tapOn(tester, find.text('Add'), 'Add in the note dialog');
      final entry = await eventually(
        tester,
        () => _read(id),
        (e) => e.notes.isNotEmpty,
        'note saved',
        seconds: 8,
        show: (e) => 'notes ${e.notes.map((n) => '${n.ms}:${n.text}')}',
      );
      final n = entry.notes.single;
      if (n.text != 'check note text' || (n.ms - 6000).abs() > 600) {
        fail(
          'expected note "check note text" at ~6000 ms; saved "${n.text}" at ${n.ms} ms',
        );
      }
      checkNote =
          'note at ${n.ms} ms; text visible: ${found(find.textContaining('check note text'))}';
    } finally {
      await _entries.doc(id).delete();
    }
  });

  check('SM-12', 'Fine-tune a section edge', (tester) async {
    await bootApp(tester);
    const id = 'check-map-tune';
    try {
      await _copySeedEntry(id);
      await _openMap(tester, id);
      await _moreMenu(tester, 'Edit');
      await tapOn(tester, byKey('marker-handle-0'), 'marker handle 0');
      await see(tester, find.text('Fine-tune M1'), 'fine-tune sheet');
      await tapOn(tester, find.text('+10 ms'), '+10 ms');
      await tapOn(tester, find.text('Done'), 'Done in the fine-tune sheet');
      final entry = await eventually(
        tester,
        () => _read(id),
        (e) => e.regions.first.endMs != 4000,
        'first boundary moved',
        seconds: 8,
        show: (e) => 'regions ${_show(e.regions)}',
      );
      final r = entry.regions;
      if (r[0].endMs != 4010 || r[1].startMs != 4010) {
        fail('expected the boundary at 4010 ms; saved ${_show(r)}');
      }
    } finally {
      await _entries.doc(id).delete();
    }
  });
  check('SM-13', 'Switching pads plays the tapped part (real audio position)', (
    tester,
  ) async {
    installAudioProbe();
    await bootApp(tester);
    final entry = await _read(seedEntryId);
    // The seed's first two sections: tapping their pads picks the whole section as the loop.
    final sections = <List<AudioRegion>>[];
    for (final r in entry.regions) {
      if (sections.isNotEmpty && sections.last.first.sectionId == r.sectionId) {
        sections.last.add(r);
      } else {
        sections.add([r]);
      }
    }
    await _openMap(tester, seedEntryId);
    final notes = <String>[];
    try {
      for (var i = 0; i < 2; i++) {
        final sec = sections[i];
        final (start, end) = (sec.first.startMs, sec.last.endMs);
        await tapOn(
          tester,
          byKey('song-map-pad-${sec.first.id}'),
          'pad of section ${sec.first.section}',
        );
        await pause(tester, 500);
        if (!_player(tester).playing) {
          await tapOn(tester, byKey('play'), 'play');
          await pumpUntil(
            tester,
            () => _player(tester).playing,
            what: 'Song Map playing',
          );
        }
        final watch = RealAudioWatch();
        // Off web a pad tapped during a loop is queued: the running pass finishes first (launchpad style).
        final queued = i > 0 && audioElementNow() == null;
        final settle = queued
            ? sections[0].last.endMs - sections[0].first.startMs + 1500
            : 1000;
        await _sampleLoop(tester, watch, settle + 2 * (end - start) + 3000);
        notes.add(
          watch.verify(
            i == 0
                ? 'first pad ${sec.first.section}'
                : 'switched to ${sec.first.section}',
            start,
            end,
            settleMs: settle,
          ),
        );
      }
    } finally {
      if (_player(tester).playing) await tapOn(tester, byKey('play'), 'pause');
    }
    checkNote = notes.join(' | ');
  });

  /// Real length of the audio in ms: the element's on web, the seeded 16 s tone elsewhere.
  Future<int> openSeedForLength(WidgetTester tester) async {
    await _openMap(tester, seedEntryId);
    final d = audioElementNow()?.duration ?? 0;
    appRouter.go('/main/home');
    await pause(tester, 500);
    return d > 0 ? (d * 1000).round() : 16000;
  }

  check('SM-14', 'Looping the last part of the song (real audio position)', (
    tester,
  ) async {
    installAudioProbe();
    await bootApp(tester);
    final total = await openSeedForLength(tester);
    const id = 'check-map-tail';
    try {
      await _copySeedEntry(
        id,
        edit: (e) {
          e['regions'] = [
            for (final (i, r) in [
              (total - 8000, total - 4000),
              (total - 4000, total),
            ].indexed)
              {
                'id': 'tail-$i',
                'name': 'Tail ${i + 1}',
                'startMs': r.$1,
                'endMs': r.$2,
                'sectionId': 'sec-tail',
                'section': 'Tail',
              },
          ];
          return e;
        },
      );
      await _openMap(tester, id);
      await tapOn(tester, byKey('song-map-pad-tail-0'), 'Tail pad');
      await pause(tester, 500);
      await tapOn(tester, byKey('play'), 'play');
      await pumpUntil(
        tester,
        () => _player(tester).playing,
        what: 'Song Map playing',
      );
      final watch = RealAudioWatch();
      await _sampleLoop(tester, watch, 2 * 8000 + 4000);
      try {
        checkNote =
            'file ${total}ms; ${watch.verify('last section', total - 8000, total)}';
      } finally {
        if (_player(tester).playing)
          await tapOn(tester, byKey('play'), 'pause');
      }
    } finally {
      await _entries.doc(id).delete();
    }
  });

  check('SM-15', 'Loop off plays the part once from its start, then stops', (
    tester,
  ) async {
    installAudioProbe();
    await bootApp(tester);
    final entry = await _read(seedEntryId);
    final sec = entry.regions
        .where((r) => r.sectionId == entry.regions.last.sectionId)
        .toList();
    final (start, end) = (sec.first.startMs, sec.last.endMs);
    await _openMap(tester, seedEntryId);
    await tapOn(
      tester,
      byKey('song-map-pad-${sec.first.id}'),
      'last section pad',
    );
    await pause(tester, 500);
    await tapOn(tester, byKey('loop'), 'Loop off');
    await pause(tester, 500);
    final watch = RealAudioWatch();
    var stoppedAt = -1;
    try {
      await tapOn(tester, byKey('play'), 'play');
      await pumpUntil(
        tester,
        () => _player(tester).playing,
        what: 'Song Map playing',
      );
      final clock = Stopwatch()..start();
      while (clock.elapsedMilliseconds < (end - start) + 5000) {
        await pause(tester, 100);
        watch.sample(clock.elapsedMilliseconds, _player(tester).pos);
        if (!_player(tester).playing) {
          stoppedAt = clock.elapsedMilliseconds;
          break;
        }
      }
    } finally {
      if (_player(tester).playing) await tapOn(tester, byKey('play'), 'pause');
    }
    final ms = watch.samples.map((s) => s.ms).toList();
    final summary =
        'part [$start..$end] ${watch.samples.first.real ? 'REAL' : 'app'} first ${ms.first} max '
        '${ms.reduce((a, b) => a > b ? a : b)} stopped at +${stoppedAt}ms, app position after stop ${_player(tester).pos}';
    if (ms.first < start - 600 || ms.first > start + 1500)
      throw TestFailure('did not start at the part start; $summary');
    if (ms.any((m) => m > end + 600))
      throw TestFailure('played past the part end; $summary');
    // The sample taken once it stopped shows the rewind to the part start; only the playing ones count.
    final run = stoppedAt >= 0 ? ms.sublist(0, ms.length - 1) : ms;
    for (var i = 1; i < run.length; i++) {
      if (run[i] < run[i - 1] - 300)
        throw TestFailure('looped although Loop is off; $summary');
    }
    if (stoppedAt < 0)
      throw TestFailure('did not stop after the part; $summary${_tailLog()}');
    final last = audioElementNow();
    if (last != null && !last.paused)
      throw TestFailure('audio element still playing after stop; $summary');
    checkNote = summary;
  });

  check(
    'SM-16',
    'Deselecting the part while playing continues, not from the top',
    (tester) async {
      installAudioProbe();
      await bootApp(tester);
      final entry = await _read(seedEntryId);
      final sec = entry.regions
          .where((r) => r.sectionId == entry.regions.last.sectionId)
          .toList();
      final (start, end) = (sec.first.startMs, sec.last.endMs);
      await _openMap(tester, seedEntryId);
      await tapOn(
        tester,
        byKey('song-map-pad-${sec.first.id}'),
        'last section pad',
      );
      await pause(tester, 500);
      final watch = RealAudioWatch();
      try {
        await tapOn(tester, byKey('play'), 'play');
        await pumpUntil(
          tester,
          () => _player(tester).playing,
          what: 'Song Map playing',
        );
        await pause(tester, 2500);
        final clock = Stopwatch()..start();
        watch.sample(0, _player(tester).pos);
        final before = watch.samples.last.ms;
        await tapOn(
          tester,
          byKey('song-map-pad-${sec.first.id}'),
          'the same pad again (deselect)',
        );
        while (clock.elapsedMilliseconds < 1800) {
          await pause(tester, 100);
          watch.sample(clock.elapsedMilliseconds, _player(tester).pos);
        }
        final ms = watch.samples.map((s) => s.ms).toList();
        final summary =
            'part [$start..$end] before deselect $before, after: ${ms.skip(1).take(8).join(' ')}';
        if (before < start)
          throw TestFailure('was not inside the part before; $summary');
        if (ms.skip(1).any((m) => m < before - 400))
          throw TestFailure(
            'jumped back after deselect; $summary${_tailLog()}',
          );
        checkNote = summary;
      } finally {
        if (_player(tester).playing)
          await tapOn(tester, byKey('play'), 'pause');
      }
    },
  );

  check('SM-17', 'Tapping the timeline inside the part seeks there', (
    tester,
  ) async {
    installAudioProbe();
    await bootApp(tester);
    final entry = await _read(seedEntryId);
    final sec = entry.regions
        .where((r) => r.sectionId == entry.regions.last.sectionId)
        .toList();
    final (start, end) = (sec.first.startMs, sec.last.endMs);
    final total = await openSeedForLength(tester);
    await _openMap(tester, seedEntryId);
    await tapOn(
      tester,
      byKey('song-map-pad-${sec.first.id}'),
      'last section pad',
    );
    await pause(tester, 500);
    final target = start + (end - start) * 3 ~/ 4;
    final watch = RealAudioWatch();
    try {
      await tapOn(tester, byKey('play'), 'play');
      await pumpUntil(
        tester,
        () => _player(tester).playing,
        what: 'Song Map playing',
      );
      await pause(tester, 800);
      await _seek(tester, target, total: total);
      final clock = Stopwatch()..start();
      while (clock.elapsedMilliseconds < 1200) {
        watch.sample(clock.elapsedMilliseconds, _player(tester).pos);
        await pause(tester, 100);
      }
    } finally {
      if (_player(tester).playing) await tapOn(tester, byKey('play'), 'pause');
    }
    final ms = watch.samples.map((s) => s.ms).toList();
    final summary = 'part [$start..$end] tapped $target: ${ms.join(' ')}';
    if (ms.any((m) => m < target - 700 || m > end + 600))
      throw TestFailure('audio not at the tapped place; $summary${_tailLog()}');
    checkNote = summary;
  });
}
