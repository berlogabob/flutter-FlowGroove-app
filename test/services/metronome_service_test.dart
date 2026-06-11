import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/models/time_signature.dart';

import '../helpers/metronome_test_runtime.dart';

void main() {
  group('MetronomeService', () {
    late ProviderContainer container;
    late MetronomeTestRuntime runtime;

    setUp(() {
      runtime = MetronomeTestRuntime();
      container = ProviderContainer(overrides: runtime.overrides);
    });

    tearDown(() async {
      container.dispose();
      await runtime.dispose();
    });

    group('initial state', () {
      test('has correct initial values', () {
        final state = container.read(metronomeProvider);

        expect(state.isPlaying, isFalse);
        expect(state.bpm, equals(120));
        expect(state.currentBeat, equals(0));
        expect(state.timeSignature, equals(TimeSignature.commonTime));
        expect(state.waveType, equals('sine'));
        expect(state.volume, equals(0.5));
        expect(state.accentEnabled, isTrue);
        expect(state.accentFrequency, equals(1600));
        expect(state.beatFrequency, equals(800));
        expect(state.accentPattern, equals([true, false, false, false]));
      });

      test('isPlaying returns false initially', () {
        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isFalse);
      });

      test('bpm returns 120 initially', () {
        final state = container.read(metronomeProvider);
        expect(state.bpm, equals(120));
      });

      test('currentBeat returns 0 initially', () {
        final state = container.read(metronomeProvider);
        expect(state.currentBeat, equals(0));
      });

      test('beatsPerMeasure returns 4 initially', () {
        final state = container.read(metronomeProvider);
        expect(state.beatsPerMeasure, equals(4));
      });

      test('timeSignature returns commonTime initially', () {
        final state = container.read(metronomeProvider);
        expect(state.timeSignature, equals(TimeSignature.commonTime));
      });

      test('waveType returns sine initially', () {
        final state = container.read(metronomeProvider);
        expect(state.waveType, equals('sine'));
      });

      test('volume returns 0.5 initially', () {
        final state = container.read(metronomeProvider);
        expect(state.volume, equals(0.5));
      });

      test('accentEnabled returns true initially', () {
        final state = container.read(metronomeProvider);
        expect(state.accentEnabled, isTrue);
      });

      test('accentFrequency returns 1600 initially', () {
        final state = container.read(metronomeProvider);
        expect(state.accentFrequency, equals(1600));
      });

      test('beatFrequency returns 800 initially', () {
        final state = container.read(metronomeProvider);
        expect(state.beatFrequency, equals(800));
      });
    });

    group('start', () {
      test('sets isPlaying to true', () {
        container.read(metronomeProvider.notifier).start();
        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isTrue);
      });

      test('preserves configured bpm and main beats', () {
        final notifier = container.read(metronomeProvider.notifier);
        notifier.setBpm(140);
        notifier.setAccentBeats(3);
        notifier.start();
        final state = container.read(metronomeProvider);
        expect(state.bpm, equals(140));
        expect(state.accentBeats, equals(3));
      });
    });

    group('stop', () {
      test('sets isPlaying to false', () {
        container.read(metronomeProvider.notifier).start();
        container.read(metronomeProvider.notifier).stop();
        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isFalse);
      });
    });

    group('setBpm', () {
      test('updates bpm value', () {
        container.read(metronomeProvider.notifier).setBpm(140);
        final state = container.read(metronomeProvider);
        expect(state.bpm, equals(140));
      });

      test('can set bpm to minimum value', () {
        container.read(metronomeProvider.notifier).setBpm(20);
        final state = container.read(metronomeProvider);
        expect(state.bpm, equals(20));
      });

      test('can set bpm to maximum value', () {
        container.read(metronomeProvider.notifier).setBpm(300);
        final state = container.read(metronomeProvider);
        expect(state.bpm, equals(300));
      });
    });

    group('setBeatsPerMeasure', () {
      test('updates time signature numerator', () {
        container.read(metronomeProvider.notifier).setBeatsPerMeasure(3);
        final state = container.read(metronomeProvider);
        expect(state.timeSignature.numerator, equals(3));
      });

      test('updates accent pattern when beats per measure changes', () {
        container.read(metronomeProvider.notifier).setBeatsPerMeasure(3);
        final state = container.read(metronomeProvider);
        expect(state.accentPattern, equals([true, false, false]));
      });
    });

    group('setTimeSignature', () {
      test('updates time signature', () {
        final waltzTime = TimeSignature(numerator: 3, denominator: 4);
        container.read(metronomeProvider.notifier).setTimeSignature(waltzTime);
        final state = container.read(metronomeProvider);
        expect(state.timeSignature, equals(waltzTime));
      });

      test('updates accent pattern when time signature changes', () {
        final waltzTime = TimeSignature(numerator: 3, denominator: 4);
        container.read(metronomeProvider.notifier).setTimeSignature(waltzTime);
        final state = container.read(metronomeProvider);
        expect(state.accentPattern, equals([true, false, false]));
      });
    });

    group('setWaveType', () {
      test('updates wave type to sine', () {
        container.read(metronomeProvider.notifier).setWaveType('sine');
        final state = container.read(metronomeProvider);
        expect(state.waveType, equals('sine'));
      });

      test('updates wave type to square', () {
        container.read(metronomeProvider.notifier).setWaveType('square');
        final state = container.read(metronomeProvider);
        expect(state.waveType, equals('square'));
      });

      test('updates wave type to triangle', () {
        container.read(metronomeProvider.notifier).setWaveType('triangle');
        final state = container.read(metronomeProvider);
        expect(state.waveType, equals('triangle'));
      });

      test('updates wave type to sawtooth', () {
        container.read(metronomeProvider.notifier).setWaveType('sawtooth');
        final state = container.read(metronomeProvider);
        expect(state.waveType, equals('sawtooth'));
      });
    });

    group('setVolume', () {
      test('updates volume', () {
        container.read(metronomeProvider.notifier).setVolume(0.8);
        final state = container.read(metronomeProvider);
        expect(state.volume, equals(0.8));
      });

      test('can set volume to 0', () {
        container.read(metronomeProvider.notifier).setVolume(0.0);
        final state = container.read(metronomeProvider);
        expect(state.volume, equals(0.0));
      });

      test('can set volume to 1', () {
        container.read(metronomeProvider.notifier).setVolume(1.0);
        final state = container.read(metronomeProvider);
        expect(state.volume, equals(1.0));
      });
    });

    group('setAccentEnabled', () {
      test('enables accent', () {
        container.read(metronomeProvider.notifier).setAccentEnabled(true);
        final state = container.read(metronomeProvider);
        expect(state.accentEnabled, isTrue);
      });

      test('disables accent', () {
        container.read(metronomeProvider.notifier).setAccentEnabled(false);
        final state = container.read(metronomeProvider);
        expect(state.accentEnabled, isFalse);
      });
    });

    group('setAccentFrequency', () {
      test('updates accent frequency', () {
        container.read(metronomeProvider.notifier).setAccentFrequency(2000);
        final state = container.read(metronomeProvider);
        expect(state.accentFrequency, equals(2000));
      });

      test('can set accent frequency to low value', () {
        container.read(metronomeProvider.notifier).setAccentFrequency(440);
        final state = container.read(metronomeProvider);
        expect(state.accentFrequency, equals(440));
      });

      test('can set accent frequency to high value', () {
        container.read(metronomeProvider.notifier).setAccentFrequency(4000);
        final state = container.read(metronomeProvider);
        expect(state.accentFrequency, equals(4000));
      });
    });

    group('setBeatFrequency', () {
      test('updates beat frequency', () {
        container.read(metronomeProvider.notifier).setBeatFrequency(600);
        final state = container.read(metronomeProvider);
        expect(state.beatFrequency, equals(600));
      });

      test('can set beat frequency to low value', () {
        container.read(metronomeProvider.notifier).setBeatFrequency(220);
        final state = container.read(metronomeProvider);
        expect(state.beatFrequency, equals(220));
      });

      test('can set beat frequency to high value', () {
        container.read(metronomeProvider.notifier).setBeatFrequency(1000);
        final state = container.read(metronomeProvider);
        expect(state.beatFrequency, equals(1000));
      });
    });

    group('setAccentPattern', () {
      test('updates accent pattern', () {
        container.read(metronomeProvider.notifier).setAccentPattern([
          true,
          true,
          false,
          false,
        ]);
        final state = container.read(metronomeProvider);
        expect(state.accentPattern, equals([true, true, false, false]));
      });

      test('updates accent pattern for 3/4 time', () {
        container.read(metronomeProvider.notifier).setAccentPattern([
          true,
          false,
          false,
        ]);
        final state = container.read(metronomeProvider);
        expect(state.accentPattern, equals([true, false, false]));
      });

      test('updates accent pattern for 6/8 time', () {
        container.read(metronomeProvider.notifier).setAccentPattern([
          true,
          false,
          false,
          true,
          false,
          false,
        ]);
        final state = container.read(metronomeProvider);
        expect(
          state.accentPattern,
          equals([true, false, false, true, false, false]),
        );
      });
    });

    group('updateAccentPatternFromTimeSignature', () {
      test('generates accent pattern for 4/4 time', () {
        container
            .read(metronomeProvider.notifier)
            .setTimeSignature(TimeSignature.commonTime);
        container
            .read(metronomeProvider.notifier)
            .updateAccentPatternFromTimeSignature();
        final state = container.read(metronomeProvider);
        expect(state.accentPattern, equals([true, false, false, false]));
      });

      test('generates accent pattern for 3/4 time', () {
        container
            .read(metronomeProvider.notifier)
            .setTimeSignature(TimeSignature.waltz);
        container
            .read(metronomeProvider.notifier)
            .updateAccentPatternFromTimeSignature();
        final state = container.read(metronomeProvider);
        expect(state.accentPattern, equals([true, false, false]));
      });

      test('generates accent pattern for 6/8 time', () {
        container
            .read(metronomeProvider.notifier)
            .setTimeSignature(TimeSignature(numerator: 6, denominator: 8));
        container
            .read(metronomeProvider.notifier)
            .updateAccentPatternFromTimeSignature();
        final state = container.read(metronomeProvider);
        expect(state.accentPattern, equals([true, true]));
      });
    });

    group('isAccentBeat', () {
      test('returns true for accented beat', () {
        final state = container.read(metronomeProvider);
        expect(state.isAccentBeat(0), isTrue);
      });

      test('returns false for non-accented beat', () {
        final state = container.read(metronomeProvider);
        expect(state.isAccentBeat(1), isFalse);
      });

      test('returns false for out of bounds beat index', () {
        final state = container.read(metronomeProvider);
        expect(state.isAccentBeat(10), isFalse);
      });

      test('returns false for negative beat index', () {
        final state = container.read(metronomeProvider);
        expect(state.isAccentBeat(-1), isFalse);
      });

      test('returns correct value for custom accent pattern', () {
        container.read(metronomeProvider.notifier).setAccentPattern([
          false,
          true,
          false,
          true,
        ]);
        final state = container.read(metronomeProvider);
        expect(state.isAccentBeat(0), isFalse);
        expect(state.isAccentBeat(1), isTrue);
      });
    });

    group('toggle', () {
      test('starts metronome when stopped', () {
        final state = container.read(metronomeProvider);
        expect(state.isPlaying, isFalse);
        container.read(metronomeProvider.notifier).toggle();
        expect(container.read(metronomeProvider).isPlaying, isTrue);
      });

      test('stops metronome when playing', () {
        container.read(metronomeProvider.notifier).start();
        expect(container.read(metronomeProvider).isPlaying, isTrue);
        container.read(metronomeProvider.notifier).toggle();
        expect(container.read(metronomeProvider).isPlaying, isFalse);
      });
    });

    group('runtime side effects', () {
      test('start starts playback and enables wakelock', () async {
        container.read(metronomeProvider.notifier).start();
        await Future<void>.delayed(Duration.zero);

        expect(runtime.playback.startCalls, 1);
        expect(runtime.playback.lastConfig?.bpm, 120);
        expect(runtime.playback.lastConfig?.accentBeats, 4);
        expect(runtime.wakelock.enableCalls, 1);
        expect(runtime.wakelock.isEnabled, isTrue);
      });

      test('stop disables wakelock cleanly', () async {
        container.read(metronomeProvider.notifier).start();
        await Future<void>.delayed(Duration.zero);

        container.read(metronomeProvider.notifier).stop();
        await Future<void>.delayed(Duration.zero);

        expect(runtime.wakelock.disableCalls, greaterThanOrEqualTo(1));
        expect(runtime.wakelock.isEnabled, isFalse);
      });

      test('playTest routes through injected audio client', () async {
        await container.read(metronomeProvider.notifier).playTest();

        expect(runtime.audio.playTestCalls, 1);
      });

      test(
        'playback tick updates current beat without platform plugins',
        () async {
          container.read(metronomeProvider.notifier).start();
          await Future<void>.delayed(Duration.zero);
          runtime.playback.emitTick(2);

          expect(container.read(metronomeProvider).currentBeat, 2);
        },
      );

      test('haptics changes update playback config while playing', () async {
        container.read(metronomeProvider.notifier).start();
        await Future<void>.delayed(Duration.zero);

        container.read(metronomeProvider.notifier).setHapticsEnabled(false);
        await Future<void>.delayed(Duration.zero);

        expect(runtime.playback.updateCalls, greaterThanOrEqualTo(1));
        expect(runtime.playback.lastConfig?.hapticsEnabled, isFalse);
      });
    });
  });
}
