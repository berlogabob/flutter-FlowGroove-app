// Cross-platform check suite. Run through scripts/check_run.sh.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flowgroove/screens/login_screen.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/screens/songs/song_page_screen.dart';
import 'package:flowgroove/screens/songs/songs_list_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'check.dart';
import 'check_account.dart';
import 'check_bands.dart';
import 'check_events.dart';
import 'check_metronome.dart';
import 'check_recorder.dart';
import 'check_setlists.dart';
import 'check_settings.dart';
import 'check_songmap.dart';
import 'check_songs.dart';
import 'check_songs_more.dart';
import 'web_probe_stub.dart' if (dart.library.js_interop) 'web_probe_web.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  reportChecksAtEnd(binding);

  check('AU-01', 'sign in with the seeded user reaches the home screen', (
    tester,
  ) async {
    await bootApp(tester, signedIn: false);
    await pumpUntil(
      tester,
      () => found(find.byType(LoginScreen)),
      what: 'login screen',
    );
    await tester.enterText(find.byType(TextFormField).at(0), seedEmail);
    await tester.enterText(find.byType(TextFormField).at(1), seedPassword);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await pumpUntil(
      tester,
      () => found(find.byType(HomeScreen)),
      what: 'home screen after sign in',
    );
    expect(FirebaseAuth.instance.currentUser?.email, seedEmail);
  });

  check('SG-01', 'the song list shows the seeded songs', (tester) async {
    await bootApp(tester);
    appRouter.go('/main/songs');
    await pumpUntil(
      tester,
      () => found(find.byType(SongsListScreen)),
      what: 'songs screen',
    );
    await pumpUntil(
      tester,
      () => seedSongTitles.every((t) => found(find.text(t))),
      what: 'seeded song titles in the list',
    );
  });

  check('SG-02', 'opening a song shows its page', (tester) async {
    await bootApp(tester);
    appRouter.go('/main/songs');
    await pumpUntil(
      tester,
      () => found(find.text(seedSongTitles.first)),
      what: 'seeded song in the list',
    );
    await tester.tap(find.text(seedSongTitles.first).first);
    await pumpUntil(
      tester,
      () => found(find.byType(SongPageScreen)),
      what: 'song page',
    );
    await pumpUntil(
      tester,
      () => found(
        find.descendant(
          of: find.byType(SongPageScreen),
          matching: find.text(seedSongTitles.first),
        ),
      ),
      what: 'song title on the song page',
    );
  });

  check('MT-01', 'metronome starts and stops', (tester) async {
    final container = await bootApp(tester);
    unawaited(appRouter.push('/main/metronome'));
    await pumpUntil(
      tester,
      () => found(find.byType(MetronomeScreen)),
      what: 'metronome screen',
    );
    bool playing() => container.read(metronomeProvider).isPlaying;
    try {
      expect(playing(), isFalse, reason: 'playing before start');
      await tester.tap(find.byIcon(Icons.play_arrow).first);
      await pumpUntil(tester, playing, what: 'metronome state playing');
      await tester.pump(const Duration(seconds: 1));
      expect(playing(), isTrue, reason: 'stopped on its own');
      await tester.tap(find.byIcon(Icons.pause).first);
      await pumpUntil(
        tester,
        () => !playing(),
        what: 'metronome state stopped',
      );
    } finally {
      if (playing()) container.read(metronomeProvider.notifier).stop();
    }
  });

  check('SM-04', 'Song Map loop stays inside the selected part', (
    tester,
  ) async {
    installAudioProbe();
    await bootApp(tester);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .doc('users/$uid/songs/$seedSongId/labEntries/$seedEntryId')
        .get();
    final entry = SongLabEntry.fromJson(doc.data()!);
    // The part under test: the second part of the first section.
    final part = entry.regions[1];
    final (partStart, partEnd) = (part.startMs, part.endMs);

    unawaited(
      appRouter.push(
        '/main/practice-regions/$seedEntryId',
        extra: {'entry': entry},
      ),
    );
    Finder byKey(String key) => find.byKey(ValueKey(key));
    await pumpUntil(
      tester,
      () => found(find.byType(PracticeRegionsScreen)),
      what: 'Song Map screen',
    );
    final playButton = byKey('play');
    await pumpUntil(
      tester,
      () =>
          found(playButton) &&
          tester.widget<FilledButton>(playButton).onPressed != null,
      what: 'audio loaded (play enabled)',
    );
    // Zoom into the first section (Shift + section pad), then pick the part.
    await tester.tap(byKey('song-map-key-Shift'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(byKey('song-map-pad-${entry.regions.first.id}'));
    await pumpUntil(
      tester,
      () => found(byKey('song-map-pad-${part.id}')),
      what: 'part pads after zoom',
    );
    await tester.tap(byKey('song-map-pad-${part.id}'));
    await tester.pump(const Duration(seconds: 1));

    ({int pos, bool playing}) read() {
      final timeline = tester.widget<SongMapTimeline>(byKey('song-map-zoom'));
      return (pos: timeline.positionMs ?? 0, playing: timeline.playing);
    }

    final samples = <(int, int)>[]; // (elapsed ms, position ms)
    final watch = RealAudioWatch();
    final wrapAt = <int>[];
    var stoppedAt = -1;
    try {
      await tester.tap(playButton);
      await pumpUntil(tester, () => read().playing, what: 'Song Map playing');
      final clock = Stopwatch()..start();
      var last = read().pos;
      // Two passes of a 4 s part, plus time for the start and a loop restart.
      while (clock.elapsedMilliseconds < 14000) {
        // Real time (pause pumps frames until the wall clock passes): on web tester.pump(duration) returns at once.
        await pause(tester, 100);
        final now = read();
        watch.sample(clock.elapsedMilliseconds, now.pos);
        if (!now.playing) {
          stoppedAt = clock.elapsedMilliseconds;
          samples.add((clock.elapsedMilliseconds, now.pos));
          break;
        }
        if (now.pos < last - (partEnd - partStart) ~/ 2) {
          wrapAt.add(clock.elapsedMilliseconds);
        }
        last = now.pos;
        samples.add((clock.elapsedMilliseconds, now.pos));
      }
    } finally {
      if (read().playing) await tester.tap(playButton);
    }

    expect(samples, isNotEmpty);
    final positions = samples.map((s) => s.$2);
    final low = positions.reduce((a, b) => a < b ? a : b);
    final high = positions.reduce((a, b) => a > b ? a : b);
    final summary =
        'part ${part.name} [$partStart..$partEnd] ms, observed $low..$high ms, '
        '${wrapAt.length} loop restarts (at ${wrapAt.map((t) => '+${t}ms').join(', ')}) in '
        '${samples.last.$1} ms, last position ${samples.last.$2} ms';
    const slack = 300;
    final outside = samples.where(
      (s) => s.$2 < partStart - slack || s.$2 > partEnd + slack,
    );
    if (outside.isNotEmpty) {
      final s = outside.first;
      throw TestFailure(
        'position left the part: ${s.$2} ms at +${s.$1} ms; $summary',
      );
    }
    if (stoppedAt >= 0) {
      throw TestFailure('playback stopped at +$stoppedAt ms; $summary');
    }
    if (wrapAt.length < 2) throw TestFailure('did not loop twice; $summary');
    checkNote =
        '$summary | ${watch.verify('part ${part.name}', partStart, partEnd)}';
  });

  registerAccountChecks();
  registerSongsChecks();
  registerSongsMoreChecks();
  registerBandsChecks();
  registerEventsChecks();
  registerRecorderChecks();
  registerSetlistsChecks();
  registerMetronomeChecks();
  registerSongMapChecks();
  registerSettingsChecks();
  registerAccountDeleteCheck();
}
