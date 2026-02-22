import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/services/audio/metronome_service.dart';
import 'package:flutter_repsync_app/models/time_signature.dart';
import 'package:flutter_repsync_app/models/metronome_state.dart';
import 'package:flutter_repsync_app/providers/data/metronome_provider.dart';

void main() {
  group('MetronomeService', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('initial state', () {
      test('has correct initial values', () {
        final service = MetronomeService(container);
        final state = service.state;

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
        final service = MetronomeService(container);
        expect(service.isPlaying, isFalse);
      });

      test('bpm returns 120 initially', () {
        final service = MetronomeService(container);
        expect(service.bpm, equals(120));
      });

      test('currentBeat returns 0 initially', () {
        final service = MetronomeService(container);
        expect(service.currentBeat, equals(0));
      });

      test('beatsPerMeasure returns 4 initially', () {
        final service = MetronomeService(container);
        expect(service.beatsPerMeasure, equals(4));
      });

      test('timeSignature returns commonTime initially', () {
        final service = MetronomeService(container);
        expect(service.timeSignature, equals(TimeSignature.commonTime));
      });

      test('waveType returns sine initially', () {
        final service = MetronomeService(container);
        expect(service.waveType, equals('sine'));
      });

      test('volume returns 0.5 initially', () {
        final service = MetronomeService(container);
        expect(service.volume, equals(0.5));
      });

      test('accentEnabled returns true initially', () {
        final service = MetronomeService(container);
        expect(service.accentEnabled, isTrue);
      });

      test('accentFrequency returns 1600 initially', () {
        final service = MetronomeService(container);
        expect(service.accentFrequency, equals(1600));
      });

      test('beatFrequency returns 800 initially', () {
        final service = MetronomeService(container);
        expect(service.beatFrequency, equals(800));
      });
    });

    group('start', () {
      test('sets isPlaying to true', () {
        final service = MetronomeService(container);
        service.start(120, 4);

        expect(service.isPlaying, isTrue);
        expect(service.bpm, equals(120));
        expect(service.beatsPerMeasure, equals(4));
      });

      test('updates bpm and beatsPerMeasure', () {
        final service = MetronomeService(container);
        service.start(140, 3);

        expect(service.bpm, equals(140));
        expect(service.beatsPerMeasure, equals(3));
        expect(service.isPlaying, isTrue);
      });
    });

    group('stop', () {
      test('sets isPlaying to false', () {
        final service = MetronomeService(container);
        service.start(120, 4);
        service.stop();

        expect(service.isPlaying, isFalse);
      });
    });

    group('setBpm', () {
      test('updates bpm value', () {
        final service = MetronomeService(container);
        service.setBpm(140);

        expect(service.bpm, equals(140));
      });

      test('can set bpm to minimum value', () {
        final service = MetronomeService(container);
        service.setBpm(20);

        expect(service.bpm, equals(20));
      });

      test('can set bpm to maximum value', () {
        final service = MetronomeService(container);
        service.setBpm(300);

        expect(service.bpm, equals(300));
      });
    });

    group('setBeatsPerMeasure', () {
      test('updates beats per measure', () {
        final service = MetronomeService(container);
        service.setBeatsPerMeasure(3);

        expect(service.beatsPerMeasure, equals(3));
      });

      test('updates accent pattern when beats per measure changes', () {
        final service = MetronomeService(container);
        service.setBeatsPerMeasure(3);

        expect(service.accentPattern.length, equals(3));
      });
    });

    group('setTimeSignature', () {
      test('updates time signature', () {
        final service = MetronomeService(container);
        final waltzTime = TimeSignature(numerator: 3, denominator: 4);
        service.setTimeSignature(waltzTime);

        expect(service.timeSignature, equals(waltzTime));
        expect(service.beatsPerMeasure, equals(3));
      });

      test('updates accent pattern when time signature changes', () {
        final service = MetronomeService(container);
        final waltzTime = TimeSignature(numerator: 3, denominator: 4);
        service.setTimeSignature(waltzTime);

        expect(service.accentPattern.length, equals(3));
        expect(service.accentPattern.first, isTrue);
      });
    });

    group('setWaveType', () {
      test('updates wave type to sine', () {
        final service = MetronomeService(container);
        service.setWaveType('sine');

        expect(service.waveType, equals('sine'));
      });

      test('updates wave type to square', () {
        final service = MetronomeService(container);
        service.setWaveType('square');

        expect(service.waveType, equals('square'));
      });

      test('updates wave type to triangle', () {
        final service = MetronomeService(container);
        service.setWaveType('triangle');

        expect(service.waveType, equals('triangle'));
      });

      test('updates wave type to sawtooth', () {
        final service = MetronomeService(container);
        service.setWaveType('sawtooth');

        expect(service.waveType, equals('sawtooth'));
      });
    });

    group('setVolume', () {
      test('updates volume', () {
        final service = MetronomeService(container);
        service.setVolume(0.8);

        expect(service.volume, equals(0.8));
      });

      test('can set volume to 0', () {
        final service = MetronomeService(container);
        service.setVolume(0.0);

        expect(service.volume, equals(0.0));
      });

      test('can set volume to 1', () {
        final service = MetronomeService(container);
        service.setVolume(1.0);

        expect(service.volume, equals(1.0));
      });
    });

    group('setAccentEnabled', () {
      test('enables accent', () {
        final service = MetronomeService(container);
        service.setAccentEnabled(true);

        expect(service.accentEnabled, isTrue);
      });

      test('disables accent', () {
        final service = MetronomeService(container);
        service.setAccentEnabled(false);

        expect(service.accentEnabled, isFalse);
      });
    });

    group('setAccentFrequency', () {
      test('updates accent frequency', () {
        final service = MetronomeService(container);
        service.setAccentFrequency(2000);

        expect(service.accentFrequency, equals(2000));
      });

      test('can set accent frequency to low value', () {
        final service = MetronomeService(container);
        service.setAccentFrequency(440);

        expect(service.accentFrequency, equals(440));
      });

      test('can set accent frequency to high value', () {
        final service = MetronomeService(container);
        service.setAccentFrequency(4000);

        expect(service.accentFrequency, equals(4000));
      });
    });

    group('setBeatFrequency', () {
      test('updates beat frequency', () {
        final service = MetronomeService(container);
        service.setBeatFrequency(600);

        expect(service.beatFrequency, equals(600));
      });

      test('can set beat frequency to low value', () {
        final service = MetronomeService(container);
        service.setBeatFrequency(220);

        expect(service.beatFrequency, equals(220));
      });

      test('can set beat frequency to high value', () {
        final service = MetronomeService(container);
        service.setBeatFrequency(1000);

        expect(service.beatFrequency, equals(1000));
      });
    });

    group('setAccentPattern', () {
      test('updates accent pattern', () {
        final service = MetronomeService(container);
        service.setAccentPattern([true, true, false, false]);

        expect(service.accentPattern, equals([true, true, false, false]));
      });

      test('updates accent pattern for 3/4 time', () {
        final service = MetronomeService(container);
        service.setAccentPattern([true, false, false]);

        expect(service.accentPattern, equals([true, false, false]));
        expect(service.accentPattern.length, equals(3));
      });

      test('updates accent pattern for 6/8 time', () {
        final service = MetronomeService(container);
        service.setAccentPattern([true, false, false, true, false, false]);

        expect(
          service.accentPattern,
          equals([true, false, false, true, false, false]),
        );
        expect(service.accentPattern.length, equals(6));
      });
    });

    group('updateAccentPatternFromTimeSignature', () {
      test('generates accent pattern for 4/4 time', () {
        final service = MetronomeService(container);
        service.setTimeSignature(TimeSignature.commonTime);
        service.updateAccentPatternFromTimeSignature();

        expect(service.accentPattern, equals([true, false, false, false]));
      });

      test('generates accent pattern for 3/4 time', () {
        final service = MetronomeService(container);
        service.setTimeSignature(TimeSignature.waltz);
        service.updateAccentPatternFromTimeSignature();

        expect(service.accentPattern.length, equals(3));
        expect(service.accentPattern.first, isTrue);
      });

      test('generates accent pattern for 6/8 time', () {
        final service = MetronomeService(container);
        service.setTimeSignature(TimeSignature(numerator: 6, denominator: 8));
        service.updateAccentPatternFromTimeSignature();

        expect(service.accentPattern.length, equals(6));
        expect(service.accentPattern.first, isTrue);
      });
    });

    group('isAccentBeat', () {
      test('returns true for accented beat', () {
        final service = MetronomeService(container);
        expect(service.isAccentBeat(0), isTrue);
      });

      test('returns false for non-accented beat', () {
        final service = MetronomeService(container);
        expect(service.isAccentBeat(1), isFalse);
      });

      test('returns false for out of bounds beat index', () {
        final service = MetronomeService(container);
        expect(service.isAccentBeat(10), isFalse);
      });

      test('returns false for negative beat index', () {
        final service = MetronomeService(container);
        expect(service.isAccentBeat(-1), isFalse);
      });

      test('returns correct value for custom accent pattern', () {
        final service = MetronomeService(container);
        service.setAccentPattern([false, true, false, true]);

        expect(service.isAccentBeat(0), isFalse);
        expect(service.isAccentBeat(1), isTrue);
        expect(service.isAccentBeat(2), isFalse);
        expect(service.isAccentBeat(3), isTrue);
      });
    });

    group('toggle', () {
      test('starts metronome when stopped', () {
        final service = MetronomeService(container);
        expect(service.isPlaying, isFalse);

        service.toggle();

        expect(service.isPlaying, isTrue);
      });

      test('stops metronome when playing', () {
        final service = MetronomeService(container);
        service.start(120, 4);
        expect(service.isPlaying, isTrue);

        service.toggle();

        expect(service.isPlaying, isFalse);
      });
    });

    group('MetronomeState', () {
      test('initial state is correct', () {
        final state = MetronomeState.initial();

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

      test('copyWith creates new state with updated values', () {
        final state = MetronomeState.initial();
        final newState = state.copyWith(
          isPlaying: true,
          bpm: 140,
          currentBeat: 1,
        );

        expect(newState.isPlaying, isTrue);
        expect(newState.bpm, equals(140));
        expect(newState.currentBeat, equals(1));
        // Original state unchanged
        expect(state.isPlaying, isFalse);
        expect(state.bpm, equals(120));
      });

      test('copyWith preserves unchanged values', () {
        final state = MetronomeState.initial();
        final newState = state.copyWith(bpm: 140);

        expect(newState.bpm, equals(140));
        expect(newState.waveType, equals(state.waveType));
        expect(newState.volume, equals(state.volume));
        expect(newState.accentPattern, equals(state.accentPattern));
      });

      test('isAccentBeat returns correct value', () {
        final state = MetronomeState.initial();
        expect(state.isAccentBeat(0), isTrue);
        expect(state.isAccentBeat(1), isFalse);
        expect(state.isAccentBeat(2), isFalse);
        expect(state.isAccentBeat(3), isFalse);
      });

      test('isAccentBeat handles out of bounds', () {
        final state = MetronomeState.initial();
        expect(state.isAccentBeat(-1), isFalse);
        expect(state.isAccentBeat(10), isFalse);
      });

      test('equality works correctly', () {
        final state1 = MetronomeState.initial();
        final state2 = MetronomeState.initial();
        final state3 = state1.copyWith(bpm: 140);

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });

      test('hashCode is consistent', () {
        final state1 = MetronomeState.initial();
        final state2 = MetronomeState.initial();

        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('toString returns formatted string', () {
        final state = MetronomeState.initial();
        final str = state.toString();

        expect(str, contains('MetronomeState'));
        expect(str, contains('isPlaying'));
        expect(str, contains('bpm'));
      });

      test('beatsPerMeasure returns numerator from time signature', () {
        final state = MetronomeState.initial();
        expect(state.beatsPerMeasure, equals(4));

        final waltzState = state.copyWith(
          timeSignature: TimeSignature(numerator: 3, denominator: 4),
        );
        expect(waltzState.beatsPerMeasure, equals(3));
      });
    });

    group('TimeSignature', () {
      test('commonTime is 4/4', () {
        expect(TimeSignature.commonTime.numerator, equals(4));
        expect(TimeSignature.commonTime.denominator, equals(4));
      });

      test('waltz is 3/4', () {
        expect(TimeSignature.waltz.numerator, equals(3));
        expect(TimeSignature.waltz.denominator, equals(4));
      });

      test('cutTime is 2/2', () {
        expect(TimeSignature.cutTime.numerator, equals(2));
        expect(TimeSignature.cutTime.denominator, equals(2));
      });

      test('isValid returns true for valid time signatures', () {
        expect(
          const TimeSignature(numerator: 4, denominator: 4).isValid,
          isTrue,
        );
        expect(
          const TimeSignature(numerator: 3, denominator: 4).isValid,
          isTrue,
        );
        expect(
          const TimeSignature(numerator: 6, denominator: 8).isValid,
          isTrue,
        );
        expect(
          const TimeSignature(numerator: 2, denominator: 4).isValid,
          isTrue,
        );
        expect(
          const TimeSignature(numerator: 12, denominator: 8).isValid,
          isTrue,
        );
      });

      test('isValid returns false for invalid numerator', () {
        expect(
          const TimeSignature(numerator: 1, denominator: 4).isValid,
          isFalse,
        );
        expect(
          const TimeSignature(numerator: 13, denominator: 4).isValid,
          isFalse,
        );
      });

      test('isValid returns false for invalid denominator', () {
        expect(
          const TimeSignature(numerator: 4, denominator: 2).isValid,
          isFalse,
        );
        expect(
          const TimeSignature(numerator: 4, denominator: 16).isValid,
          isFalse,
        );
      });

      test('displayName returns formatted string', () {
        expect(
          const TimeSignature(numerator: 4, denominator: 4).displayName,
          equals('4 / 4'),
        );
        expect(
          const TimeSignature(numerator: 6, denominator: 8).displayName,
          equals('6 / 8'),
        );
      });

      test('fromString parses valid strings', () {
        expect(
          TimeSignature.fromString('4/4'),
          equals(const TimeSignature(numerator: 4, denominator: 4)),
        );
        expect(
          TimeSignature.fromString('6 / 8'),
          equals(const TimeSignature(numerator: 6, denominator: 8)),
        );
        expect(
          TimeSignature.fromString('3/4'),
          equals(const TimeSignature(numerator: 3, denominator: 4)),
        );
      });

      test('fromString returns null for invalid strings', () {
        expect(TimeSignature.fromString('invalid'), isNull);
        expect(TimeSignature.fromString(''), isNull);
        expect(TimeSignature.fromString('4'), isNull);
        expect(TimeSignature.fromString('4/4/4'), isNull);
        expect(TimeSignature.fromString('a/b'), isNull);
      });

      test('equality works correctly', () {
        const ts1 = TimeSignature(numerator: 4, denominator: 4);
        const ts2 = TimeSignature(numerator: 4, denominator: 4);
        const ts3 = TimeSignature(numerator: 3, denominator: 4);

        expect(ts1, equals(ts2));
        expect(ts1, isNot(equals(ts3)));
      });

      test('hashCode is consistent', () {
        const ts1 = TimeSignature(numerator: 4, denominator: 4);
        const ts2 = TimeSignature(numerator: 4, denominator: 4);

        expect(ts1.hashCode, equals(ts2.hashCode));
      });

      test('presets contains expected time signatures', () {
        expect(TimeSignature.presets.length, equals(8));
        expect(
          TimeSignature.presets,
          contains(const TimeSignature(numerator: 4, denominator: 4)),
        );
        expect(
          TimeSignature.presets,
          contains(const TimeSignature(numerator: 3, denominator: 4)),
        );
        expect(
          TimeSignature.presets,
          contains(const TimeSignature(numerator: 6, denominator: 8)),
        );
      });
    });
  });
}
