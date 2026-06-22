import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowgroove/providers/metronome_runtime_providers.dart'
    show MetronomePlaybackClient;
import 'package:flowgroove/services/audio/engine/unified_engine_playback_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('satisfies the MetronomePlaybackClient contract', () {
    final client = UnifiedEnginePlaybackClient();
    expect(client, isA<MetronomePlaybackClient>());
    // Dispose immediately; must not throw. (No real audio is started, so the
    // SoLoud sink is never opened here.)
    expect(client.dispose, returnsNormally);
  });

  test('construct + dispose without starting does not throw', () {
    expect(() => UnifiedEnginePlaybackClient()..dispose(), returnsNormally);
  });

  // NOTE on route-handling (Fix 1 + 2) test coverage:
  //
  // The route-handling logic in `_subscribeRoute` (skip `signalDeviceChanged`
  // on the first `AudioRouteMonitor.routeChanges` emission after (re)subscribe;
  // signal it on subsequent *different* emissions only) was verified
  // interactively against a real `NativeSoLoudSink` + a mocked `EventChannel`
  // (via `TestDefaultBinaryMessengerBinding`/`MockStreamHandler`) while writing
  // this fix, confirming the intended behavior. It is NOT included as an
  // automated test here because doing so is not safely reproducible headless
  // in this repo's test harness:
  //   - `UnifiedEnginePlaybackClient.start()` drives a REAL (non-test-mode)
  //     `MetronomeScheduler`, which starts a real periodic `Timer`. Once that
  //     timer is running, any subsequent real-time-based await in the test
  //     (`Future.delayed`, `pumpEventQueue()`) deadlocks the test runner —
  //     confirmed experimentally (hangs past its own `Timeout`, requiring the
  //     process to be killed).
  //   - Wrapping the same scenario in `package:fake_async`'s `fakeAsync` avoids
  //     the deadlock, but `EventChannel`/`MockStreamHandler` message delivery
  //     does not fire inside `fakeAsync`'s simulated zone (confirmed: the
  //     route listener is never invoked), so the route emission can't be
  //     observed that way either.
  // Bottom line: exercising the real route-change path needs either a runtime
  // seam (e.g. an injectable `testMode` on `MetronomeScheduler`, exposed
  // through this client) or on-device verification. Recommended follow-up:
  // verify on a real device/emulator by toggling Bluetooth/wired routes during
  // playback and confirming (a) no audible glitch immediately after `start()`,
  // and (b) a clean recovery glitch only on an actual route change.
}
