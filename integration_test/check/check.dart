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
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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
