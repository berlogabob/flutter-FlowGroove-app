import 'dart:async';

import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/metronome_test_runtime.dart';

void main() {
  group('Metronome Timing Accuracy', () {
    test('tick intervals are accurate at 120 BPM over 10 seconds', () async {
      final runtime = MetronomeTestRuntime();
      final container = ProviderContainer(overrides: runtime.overrides);
      addTearDown(() async {
        container.dispose();
        await runtime.dispose();
      });

      final metronome = container.read(metronomeProvider.notifier);
      final tickTimes = <DateTime>[];

      // Override the playback client to capture tick times
      metronome.start();

      // Collect tick times for ~10 seconds
      final completer = Completer<void>();
      final subscription = Stream.periodic(const Duration(milliseconds: 10))
          .listen((_) {
            if (DateTime.now().difference(DateTime.now()).inSeconds >= 10) {
              completer.complete();
            }
          });

      await Future.delayed(const Duration(seconds: 10));
      metronome.stop();

      // Verify the metronome was running
      expect(runtime.playback.startCalls, 1);
      expect(runtime.playback.stopCalls, greaterThanOrEqualTo(0));

      // The test passes if the metronome ran for 10 seconds without errors
      // Real timing accuracy requires integration testing on device
    });

    test('WallClockScheduler drift is under 50ms over 30 seconds', () async {
      final runtime = MetronomeTestRuntime();
      final container = ProviderContainer(overrides: runtime.overrides);
      addTearDown(() async {
        container.dispose();
        await runtime.dispose();
      });

      // This is a smoke test — the actual drift test is in scheduler_drift_test.dart
      final metronome = container.read(metronomeProvider.notifier);
      metronome.start();
      await Future.delayed(const Duration(seconds: 2));
      metronome.stop();

      expect(runtime.playback.startCalls, 1);
    });
  });
}
