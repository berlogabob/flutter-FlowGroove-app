// Shared pieces of the cross-platform check suite: the `check` helper that
// records one result per check, and booting the real app against the emulators.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flowgroove/firebase_options.dart';
import 'package:flowgroove/main.dart' as app;
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flowgroove/screens/login_screen.dart';
import 'package:flowgroove/screens/songs/song_page_screen.dart';
import 'package:flowgroove/screens/songs/songs_list_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ErrorWidget, Scrollable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' show Text, TextField;

/// How the app under test reaches the emulators: 127.0.0.1 on Android (adb
/// reverse) and web, the Mac's LAN address on iOS (set by scripts/check_run.sh).
const emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

/// Mirrors scripts/check_seed.py.
const seedEmail = 'check@flowgroove.test';
const seedPassword = 'Password123!';
const seedSongTitles = ['Check Song Alpha', 'Check Song Beta', 'Check Song Gamma'];
const seedSongId = 'check-song-1';
const seedEntryId = 'check-entry';

/// Dev filter: `CHECK_ONLY=SG,SL-01 scripts/check_run.sh web` runs only matching ids.
const _only = String.fromEnvironment('CHECK_ONLY');

final _results = <Map<String, Object?>>[];

/// A check may set this to leave a note on its result, also when it passes.
String checkNote = '';

/// Throw from a check body to record it as skipped.
class CheckSkip implements Exception {
  CheckSkip(this.reason);
  final String reason;
}

String get platformName =>
    kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

/// Registers one check. A failing check is recorded and never stops the rest.
void check(
  String id,
  String title,
  Future<void> Function(WidgetTester tester) body,
) {
  if (_only.isNotEmpty && !_only.split(',').any(id.startsWith)) return;
  testWidgets('$id $title', (tester) async {
    final watch = Stopwatch()..start();
    // The app's main() installs its own ErrorWidget.builder; the test binding
    // fails a test that leaves it changed.
    final errorWidgetBuilder = ErrorWidget.builder;
    addTearDown(() => ErrorWidget.builder = errorWidgetBuilder);
    var status = 'pass';
    var message = '';
    checkNote = '';
    try {
      await body(tester);
      message = checkNote;
    } on CheckSkip catch (e) {
      status = 'skip';
      message = e.reason;
    } catch (e) {
      status = 'fail';
      message = e.toString();
    }
    // Stray framework errors (overflows etc.) must not fail the whole run.
    tester.takeException();
    _results.add({
      'id': id,
      'title': title,
      'status': status,
      'message': message,
      'ms': watch.elapsedMilliseconds,
    });
    debugPrint('CHECK $id $status ${watch.elapsedMilliseconds}ms $message');
  }, timeout: const Timeout(Duration(minutes: 4)));
}

/// Call once from main(): hands the collected results to the flutter drive
/// driver (test_driver/check_driver.dart), which writes build/check/PLATFORM.json.
void reportChecksAtEnd(IntegrationTestWidgetsFlutterBinding binding) {
  tearDownAll(() {
    binding.reportData = <String, dynamic>{
      'platform': platformName,
      'results': _results,
    };
  });
}

bool _emulatorsSet = false;

/// Firebase default app pointed at the emulators, before the app's own main()
/// runs (main() reuses an existing default app).
Future<void> bootFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  if (!_emulatorsSet) {
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    _emulatorsSet = true;
  }
}

/// Runs the real main() and waits for the home screen (or the login screen).
/// With [signedIn], a missing session is restored through the Auth API.
Future<ProviderContainer> bootApp(
  WidgetTester tester, {
  bool signedIn = true,
}) async {
  await bootFirebase();
  final auth = FirebaseAuth.instance;
  if (signedIn && auth.currentUser == null) {
    await auth.signInWithEmailAndPassword(
      email: seedEmail,
      password: seedPassword,
    );
  } else if (!signedIn && auth.currentUser != null) {
    await auth.signOut();
  }
  // main() is declared `void` but is async: await the Future it really returns.
  final booted = (app.main as dynamic)();
  if (booted is Future) await booted;
  await pumpUntil(
    tester,
    () => found(find.byType(app.FlowGrooveApp)),
    what: 'app root',
  );
  // The router is a process-wide singleton: it keeps the previous check's location.
  if (signedIn) appRouter.go('/main/home');
  await pumpUntil(
    tester,
    () => found(find.byType(signedIn ? HomeScreen : LoginScreen)),
    what: signedIn ? 'home screen' : 'login screen',
  );
  return ProviderScope.containerOf(tester.element(find.byType(app.FlowGrooveApp)));
}

/// pumpAndSettle never settles on this app (tickers, loaders): poll instead.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 30),
  String what = 'condition',
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('timed out after ${timeout.inSeconds}s waiting for $what');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool found(Finder finder) => finder.evaluate().isNotEmpty;

// --- small shared helpers for the area files ---------------------------------

Finder byKey(String key) => find.byKey(ValueKey(key));

/// A Text widget showing [text] (find.text also matches a typed-in text field).
Finder label(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text, description: 'Text "$text"');

/// Pumps for [ms] of real time (async work like Firestore needs wall-clock time).
Future<void> pause(WidgetTester tester, [int ms = 400]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Waits until [finder] matches; the timeout message names [what].
Future<void> see(
  WidgetTester tester,
  Finder finder,
  String what, {
  int seconds = 20,
}) => pumpUntil(
  tester,
  () => found(finder),
  timeout: Duration(seconds: seconds),
  what: what,
);

/// Waits for [finder], taps its first match, lets the UI react.
Future<void> tapOn(WidgetTester tester, Finder finder, String what) async {
  await see(tester, finder, what);
  await tester.tap(finder.first);
  await pause(tester, 300);
}

Future<void> typeInto(
  WidgetTester tester,
  Finder finder,
  String text,
  String what,
) async {
  await see(tester, finder, what);
  await tester.enterText(finder.first, text);
  await pause(tester, 150);
}

/// Scrolls the scrollable inside [within] until [finder] is on screen.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder,
  Finder within,
  String what,
) async {
  await see(tester, within, 'scroll area for $what');
  if (!found(finder)) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(of: within, matching: find.byType(Scrollable))
          .first,
    );
  } else {
    await tester.ensureVisible(finder.first);
  }
  await pause(tester, 200);
}

/// Polls [read] (a Firestore read or provider read) until [ok] holds.
Future<T> eventually<T>(
  WidgetTester tester,
  Future<T> Function() read,
  bool Function(T value) ok,
  String what, {
  int seconds = 15,
  String Function(T value)? show,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  late T last;
  while (true) {
    last = await read();
    if (ok(last)) return last;
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('$what: not reached in ${seconds}s, last value ${show == null ? last : show(last)}');
    }
    await pause(tester, 250);
  }
}

String get uid => FirebaseAuth.instance.currentUser!.uid;

DocumentReference<Map<String, dynamic>> songDoc(String id) =>
    FirebaseFirestore.instance.doc('users/$uid/songs/$id');

/// Writes a song the way scripts/check_seed.py does, for checks that need
/// their own data (so they never change the seeded songs).
Future<void> putSong(
  String id,
  String title, {
  String artist = 'Check Band',
  String? key,
  int? bpm,
  List<String> tags = const [],
  List<Map<String, dynamic>> sections = const [],
}) {
  final now = DateTime.now().toIso8601String();
  return songDoc(id).set({
    'id': id,
    'title': title,
    'artist': artist,
    'originalKey': key,
    'originalBPM': bpm,
    'ourKey': key,
    'ourBPM': bpm,
    'tags': tags,
    'sections': sections,
    'createdAt': now,
    'updatedAt': now,
  });
}

Future<Map<String, dynamic>?> readSong(String id) async =>
    (await songDoc(id).get()).data();

/// Opens the Songs tab and waits for the seeded songs.
Future<void> openSongsTab(WidgetTester tester) async {
  appRouter.go('/main/songs');
  await see(tester, find.byType(SongsListScreen), 'songs screen');
  await see(
    tester,
    find.text(seedSongTitles.first),
    'seeded song in the songs list',
  );
}

Finder get songSearchField => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'Search...',
);

/// Songs tab, search for [title], tap the card: lands on the Song Page.
Future<void> openSongPage(WidgetTester tester, String title) async {
  await openSongsTab(tester);
  await typeInto(tester, songSearchField, title, 'song search field');
  await tapOn(tester, label(title), 'song "$title" in the list');
  await see(tester, find.byType(SongPageScreen), 'song page');
}

/// The shell bar's Menu / More button.
Future<void> openShellMenu(WidgetTester tester) async {
  await tapOn(tester, find.text('Menu'), 'Menu button in the bottom bar');
}

/// Opens the shell menu and taps the row labelled [label].
Future<void> menuAction(WidgetTester tester, String label) async {
  await openShellMenu(tester);
  await tapOn(tester, find.text(label), 'menu row "$label"');
}
