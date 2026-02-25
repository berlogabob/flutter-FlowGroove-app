import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/providers/tuner_provider.dart';

void main() {
  group('TunerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    group('Tuner State Initialization', () {
      test('tunerProvider initializes with default state', () {
        final state = container.read(tunerProvider);
        expect(state, isNotNull);
        expect(state.mode, TunerMode.listen);
        expect(state.frequency, 440.0);
        expect(state.note, 'A4');
        expect(state.cents, 0);
        expect(state.isPlaying, isFalse);
        expect(state.isListening, isFalse);
        expect(state.volume, 0.5);
      });

      test('TunerState.initial creates correct default state', () {
        final state = TunerState.initial();
        expect(state.mode, TunerMode.listen);
        expect(state.frequency, 440.0);
        expect(state.note, 'A4');
        expect(state.cents, 0);
        expect(state.isPlaying, isFalse);
        expect(state.isListening, isFalse);
        expect(state.volume, 0.5);
      });

      test('TunerState copyWith creates new instance', () {
        const originalState = TunerState();
        final newState = originalState.copyWith(frequency: 880.0);

        expect(originalState.frequency, 440.0);
        expect(newState.frequency, 880.0);
        expect(newState.mode, originalState.mode);
      });

      test('TunerState copyWith preserves unchanged values', () {
        const originalState = TunerState();
        final newState = originalState.copyWith(frequency: 880.0);

        expect(newState.mode, originalState.mode);
        expect(newState.note, originalState.note);
        expect(newState.volume, originalState.volume);
      });

      test('TunerState toString returns formatted string', () {
        const state = TunerState();
        final str = state.toString();
        expect(str, contains('TunerState'));
        expect(str, contains('frequency'));
      });
    });

    group('Tuner Notifier Methods', () {
      test('notifier is accessible', () {
        final notifier = container.read(tunerProvider.notifier);
        expect(notifier, isNotNull);
      });

      test('setMode switches to generate mode', () async {
        final notifier = container.read(tunerProvider.notifier);
        await notifier.setMode(TunerMode.generate);

        final state = container.read(tunerProvider);
        expect(state.mode, TunerMode.generate);
      });

      test('setMode switches to listen mode', () async {
        final notifier = container.read(tunerProvider.notifier);
        await notifier.setMode(TunerMode.generate);
        await notifier.setMode(TunerMode.listen);

        final state = container.read(tunerProvider);
        expect(state.mode, TunerMode.listen);
      });

      test('setMode same mode does nothing', () async {
        final notifier = container.read(tunerProvider.notifier);
        final initialState = container.read(tunerProvider);

        await notifier.setMode(TunerMode.listen);

        final state = container.read(tunerProvider);
        expect(state.mode, initialState.mode);
      });

      test('updateFrequency updates frequency', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.updateFrequency(880.0);

        final state = container.read(tunerProvider);
        expect(state.frequency, 880.0);
      });

      test('updateFrequency clamps to minimum 20 Hz', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.updateFrequency(10.0);

        final state = container.read(tunerProvider);
        expect(state.frequency, 20.0);
      });

      test('updateFrequency clamps to maximum 2000 Hz', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.updateFrequency(3000.0);

        final state = container.read(tunerProvider);
        expect(state.frequency, 2000.0);
      });

      test('setFrequency updates frequency', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.setFrequency(523.25);

        final state = container.read(tunerProvider);
        expect(state.frequency, 523.25);
      });

      test('setVolume updates volume', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.setVolume(0.8);

        final state = container.read(tunerProvider);
        expect(state.volume, 0.8);
      });

      test('calculateCents returns correct deviation', () {
        final notifier = container.read(tunerProvider.notifier);

        // A4 = 440 Hz should be 0 cents
        final cents = notifier.calculateCents(440.0);
        expect(cents, 0);
      });

      test('calculateCents clamps to -50 to 50', () {
        final notifier = container.read(tunerProvider.notifier);

        // Very high frequency should clamp to 50
        final cents = notifier.calculateCents(10000.0);
        expect(cents, inInclusiveRange(-50, 50));
      });
    });

    group('Derived Providers', () {
      test('tunerModeProvider returns current mode', () {
        final mode = container.read(tunerModeProvider);
        expect(mode, TunerMode.listen);
      });

      test('tunerFrequencyProvider returns current frequency', () {
        final frequency = container.read(tunerFrequencyProvider);
        expect(frequency, 440.0);
      });

      test('tunerNoteProvider returns current note', () {
        final note = container.read(tunerNoteProvider);
        expect(note, 'A4');
      });

      test('tunerCentsProvider returns current cents', () {
        final cents = container.read(tunerCentsProvider);
        expect(cents, 0);
      });

      test('tunerIsPlayingProvider returns playing state', () {
        final isPlaying = container.read(tunerIsPlayingProvider);
        expect(isPlaying, isFalse);
      });

      test('tunerIsListeningProvider returns listening state', () {
        final isListening = container.read(tunerIsListeningProvider);
        expect(isListening, isFalse);
      });
    });

    group('NoteData Class', () {
      test('NoteData creates correct instance', () {
        const noteData = NoteData(note: 'A', octave: 4, frequency: 440.0);

        expect(noteData.note, 'A');
        expect(noteData.octave, 4);
        expect(noteData.frequency, 440.0);
      });

      test('NoteData displayName formats correctly', () {
        const noteData = NoteData(note: 'C', octave: 4, frequency: 261.63);

        expect(noteData.displayName, 'C4');
      });

      test('NoteData toString returns displayName', () {
        const noteData = NoteData(note: 'E', octave: 5, frequency: 659.25);

        expect(noteData.toString(), 'E5');
      });
    });

    group('TunerMode Enum', () {
      test('TunerMode has generate value', () {
        expect(TunerMode.generate, isNotNull);
      });

      test('TunerMode has listen value', () {
        expect(TunerMode.listen, isNotNull);
      });
    });

    group('Dispose Verification', () {
      test('TunerNotifier dispose does not throw', () {
        final notifier = container.read(tunerProvider.notifier);
        expect(() => notifier.dispose(), returnsNormally);
      });

      test('ProviderContainer dispose cleans up resources', () {
        final localContainer = ProviderContainer();
        localContainer.read(tunerProvider);
        expect(() => localContainer.dispose(), returnsNormally);
      });
    });

    group('State Transitions', () {
      test('frequency change updates note', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.updateFrequency(523.25); // C5

        final state = container.read(tunerProvider);
        expect(state.frequency, 523.25);
        // Note should be updated based on frequency
        expect(state.note, isNotEmpty);
      });

      test('multiple frequency updates work correctly', () {
        final notifier = container.read(tunerProvider.notifier);

        notifier.updateFrequency(440.0);
        expect(container.read(tunerProvider).frequency, 440.0);

        notifier.updateFrequency(880.0);
        expect(container.read(tunerProvider).frequency, 880.0);

        notifier.updateFrequency(261.63);
        expect(container.read(tunerProvider).frequency, 261.63);
      });

      test('volume updates work correctly', () {
        final notifier = container.read(tunerProvider.notifier);

        notifier.setVolume(0.2);
        expect(container.read(tunerProvider).volume, 0.2);

        notifier.setVolume(0.9);
        expect(container.read(tunerProvider).volume, 0.9);
      });
    });

    group('Edge Cases', () {
      test('updateFrequency with exactly 20 Hz', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.updateFrequency(20.0);

        final state = container.read(tunerProvider);
        expect(state.frequency, 20.0);
      });

      test('updateFrequency with exactly 2000 Hz', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.updateFrequency(2000.0);

        final state = container.read(tunerProvider);
        expect(state.frequency, 2000.0);
      });

      test('setVolume with 0.0', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.setVolume(0.0);

        final state = container.read(tunerProvider);
        expect(state.volume, 0.0);
      });

      test('setVolume with 1.0', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.setVolume(1.0);

        final state = container.read(tunerProvider);
        expect(state.volume, 1.0);
      });

      test('calculateCents with standard frequencies', () {
        final notifier = container.read(tunerProvider.notifier);

        // Test various standard frequencies
        expect(notifier.calculateCents(440.0), inInclusiveRange(-50, 50));
        expect(notifier.calculateCents(261.63), inInclusiveRange(-50, 50));
        expect(notifier.calculateCents(523.25), inInclusiveRange(-50, 50));
      });
    });

    group('Provider Independence', () {
      test('tunerProvider works independently of other providers', () {
        final state = container.read(tunerProvider);
        expect(state, isNotNull);
      });

      test('derived providers update with tunerProvider', () {
        final notifier = container.read(tunerProvider.notifier);

        notifier.updateFrequency(880.0);

        expect(container.read(tunerFrequencyProvider), 880.0);
        expect(container.read(tunerProvider).frequency, 880.0);
      });
    });
  });
}
