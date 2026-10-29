import 'dart:async';

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/models/instrument.dart';
import 'package:flowgroove/models/tuner_preset.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/repositories/tuner_preset_repository.dart';
import 'package:mockito/mockito.dart';
import '../helpers/mocks.mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Identity extends AppUserNotifier {
  _Identity(this.initial);
  final AsyncValue<AppUser?> initial;
  @override
  AsyncValue<AppUser?> build() => initial;
  void change(AsyncValue<AppUser?> value) => state = value;
}

class _Presets extends TunerPresetRepository {
  final saved = <TunerPreset>[];
  final deleted = <TunerPreset>[];
  List<TunerPreset> loaded = [];
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<List<TunerPreset>> loadLocal() async => [];
  @override
  Future<List<TunerPreset>> loadSynced({
    String? bandId,
    String? songId,
  }) async => loaded;
  @override
  Future<void> save(TunerPreset preset) async {
    if (fail) throw StateError('offline');
    saved.add(preset);
    await pending?.future;
  }

  @override
  Future<void> delete(TunerPreset preset) async {
    if (fail) throw StateError('offline');
    deleted.add(preset);
    await pending?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'synced account save rejects demo before repository transport',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _Presets();
      final auth = MockFirebaseAuth();
      final user = MockUser();
      when(user.uid).thenReturn('u1');
      when(auth.currentUser).thenReturn(user);
      final identity = _Identity(
        AsyncValue.data(
          AppUser(uid: 'u1', accessRole: 'demo', createdAt: DateTime(2026)),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          appUserProvider.overrideWith(() => identity),
          tunerProvider.overrideWith(
            () => TunerNotifier(presetRepository: repository),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(tunerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await expectLater(
        notifier.addCustomTuning(
          const Tuning(id: 'test', name: 'Test', notes: ['E2']),
          scope: TunerPresetScope.account,
        ),
        throwsStateError,
      );
      expect(repository.saved, isEmpty);
      expect(container.read(tunerProvider).customTunings, isEmpty);
    },
  );

  test('synced delete rejects revoked identity before transport', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _Presets();
    final auth = MockFirebaseAuth();
    final user = MockUser();
    when(user.uid).thenReturn('u1');
    when(auth.currentUser).thenReturn(user);
    final identity = _Identity(
      AsyncValue.data(AppUser(uid: 'u1', createdAt: DateTime(2026))),
    );
    final container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        appUserProvider.overrideWith(() => identity),
        tunerProvider.overrideWith(
          () => TunerNotifier(presetRepository: repository),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(tunerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await notifier.addCustomTuning(
      const Tuning(id: 'test', name: 'Test', notes: ['E2']),
      scope: TunerPresetScope.account,
    );
    expect(repository.saved.single.ownerId, 'u1');
    identity.change(
      AsyncValue.data(
        AppUser(uid: 'u1', accessRole: 'demo', createdAt: DateTime(2026)),
      ),
    );
    await expectLater(notifier.removeCustomTuning('test'), throwsStateError);
    expect(repository.deleted, isEmpty);
    expect(container.read(tunerProvider).customTunings.single.id, 'test');
  });

  group('Preset write authority', () {
    late _Presets repository;
    late _Identity identity;
    late MockFirebaseAuth auth;
    late MockUser user;
    late ProviderContainer container;
    late TunerNotifier notifier;
    late StreamController<List<Band>> bands;
    final authorized = AsyncValue<AppUser?>.data(
      AppUser(uid: 'u1', createdAt: DateTime(2026)),
    );
    const tuning = Tuning(id: 'custom', name: 'Custom', notes: ['E2']);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = _Presets();
      identity = _Identity(authorized);
      auth = MockFirebaseAuth();
      user = MockUser();
      when(user.uid).thenReturn('u1');
      when(auth.currentUser).thenReturn(user);
      bands = StreamController<List<Band>>();
      container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          appUserProvider.overrideWith(() => identity),
          bandsProvider.overrideWith((ref) => bands.stream),
          tunerProvider.overrideWith(
            () => TunerNotifier(presetRepository: repository),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await bands.close();
      });
      // Subscribe before feeding the stream; use real permission providers.
      container.listen(bandsProvider, (_, _) {});
      container.read(appUserProvider);
      notifier = container.read(tunerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    for (final denied in [
      'demo',
      'signed out',
      'mismatch',
      'loading',
      'error',
      'cached loading',
      'cached error',
    ]) {
      test(
        '$denied blocks all synced saves but permits local save/delete',
        () async {
          switch (denied) {
            case 'demo':
              identity.change(
                AsyncValue.data(
                  AppUser(
                    uid: 'u1',
                    accessRole: 'demo',
                    createdAt: DateTime(2026),
                  ),
                ),
              );
            case 'signed out':
              when(auth.currentUser).thenReturn(null);
            case 'mismatch':
              when(user.uid).thenReturn('other');
            case 'loading':
              identity.change(const AsyncValue.loading());
            case 'error':
              identity.change(
                AsyncValue.error(StateError('offline'), StackTrace.current),
              );
            case 'cached loading':
              identity.change(
                // ignore: invalid_use_of_internal_member
                const AsyncValue<AppUser?>.loading().copyWithPrevious(
                  authorized,
                ),
              );
            case 'cached error':
              identity.change(
                AsyncValue<AppUser?>.error(
                  StateError('offline'),
                  StackTrace.current,
                  // ignore: invalid_use_of_internal_member
                ).copyWithPrevious(authorized),
              );
          }
          for (final scope in [
            TunerPresetScope.account,
            TunerPresetScope.band,
            TunerPresetScope.song,
          ]) {
            await expectLater(
              notifier.addCustomTuning(
                tuning,
                scope: scope,
                bandId: 'b1',
                songId: 's1',
              ),
              throwsStateError,
            );
          }
          expect(repository.saved, isEmpty);
          expect(container.read(tunerProvider).customTunings, isEmpty);
          await notifier.addCustomTuning(tuning);
          expect(repository.saved.single.scope, TunerPresetScope.local);
          await notifier.removeCustomTuning(tuning.id);
          expect(repository.deleted.single.scope, TunerPresetScope.local);
          expect(container.read(tunerProvider).customTunings, isEmpty);
        },
      );
    }

    for (final scope in [
      TunerPresetScope.account,
      TunerPresetScope.song,
      TunerPresetScope.band,
    ]) {
      test(
        '$scope authorized save/delete and failure preserve state',
        () async {
          bands.add([
            Band(
              id: 'b1',
              name: 'Band',
              createdBy: 'owner',
              createdAt: DateTime(2026),
              adminUids: ['u1'],
            ),
          ]);
          await Future<void>.delayed(Duration.zero);
          final bandId = scope == TunerPresetScope.band ? 'b1' : null;
          Future<void> save() => notifier.addCustomTuning(
            tuning,
            scope: scope,
            bandId: bandId,
            songId: 's1',
          );
          repository.fail = true;
          await expectLater(save(), throwsStateError);
          expect(container.read(tunerProvider).customTunings, isEmpty);
          repository.fail = false;
          await save();
          expect(repository.saved.single.ownerId, 'u1');
          expect(repository.saved.single.bandId, bandId);
          expect(
            container.read(tunerProvider).customTuningScopes[tuning.id],
            scope,
          );
          repository.fail = true;
          await expectLater(
            notifier.removeCustomTuning(tuning.id),
            throwsStateError,
          );
          expect(
            container.read(tunerProvider).customTunings.single.id,
            tuning.id,
          );
          repository.fail = false;
          await notifier.removeCustomTuning(tuning.id);
          expect(repository.deleted.single.id, tuning.id);
          expect(container.read(tunerProvider).customTunings, isEmpty);
        },
      );
    }

    test(
      'band authority uses live arrays and rejects retained loading/error',
      () async {
        for (final scope in [TunerPresetScope.band, TunerPresetScope.song]) {
          await expectLater(
            notifier.addCustomTuning(
              tuning,
              scope: scope,
              bandId: 'b1',
              songId: 's1',
            ),
            throwsStateError,
          );
        }
        bands.add([
          Band(
            id: 'b1',
            name: 'Band',
            createdBy: 'owner',
            createdAt: DateTime(2026),
            editorUids: ['u1'],
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        await notifier.addCustomTuning(
          tuning,
          scope: TunerPresetScope.song,
          bandId: 'b1',
          songId: 's1',
        );
        expect(repository.saved.single.bandId, 'b1');
        bands.addError(StateError('offline'));
        await Future<void>.delayed(Duration.zero);
        await expectLater(
          notifier.removeCustomTuning(tuning.id),
          throwsStateError,
        );
        bands.add([
          Band(
            id: 'b1',
            name: 'Band',
            createdBy: 'owner',
            createdAt: DateTime(2026),
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        await expectLater(
          notifier.removeCustomTuning(tuning.id),
          throwsStateError,
        );
        await expectLater(notifier.addCustomTuning(tuning), throwsStateError);
        expect(repository.deleted, isEmpty);
        expect(repository.saved, hasLength(1));
        expect(
          container.read(tunerProvider).customTunings.single.id,
          tuning.id,
        );
      },
    );

    test(
      'loaded personal preset cannot be deleted or overwritten by another owner',
      () async {
        repository.loaded = [
          TunerPreset(
            id: tuning.id,
            name: tuning.name,
            instrumentType: InstrumentType.custom,
            tuningNotes: [],
            scope: TunerPresetScope.account,
            ownerId: 'other',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ];
        await notifier.loadContextPresets();
        await expectLater(
          notifier.removeCustomTuning(tuning.id),
          throwsStateError,
        );
        await expectLater(
          notifier.addCustomTuning(tuning, scope: TunerPresetScope.account),
          throwsStateError,
        );
        expect(repository.saved, isEmpty);
        expect(repository.deleted, isEmpty);
        expect(
          container.read(tunerProvider).customTunings.single.id,
          tuning.id,
        );
      },
    );

    test('account change during save does not publish stale success', () async {
      repository.pending = Completer<void>();
      final save = notifier.addCustomTuning(
        tuning,
        scope: TunerPresetScope.account,
      );
      final assertion = expectLater(save, throwsStateError);
      when(user.uid).thenReturn('other');
      identity.change(
        AsyncValue.data(AppUser(uid: 'other', createdAt: DateTime(2026))),
      );
      repository.pending!.complete();
      await assertion;
      expect(container.read(tunerProvider).customTunings, isEmpty);
    });
  });

  group('TunerProvider', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
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
        final newState = originalState.copyWith(frequency: 880);

        expect(originalState.frequency, 440.0);
        expect(newState.frequency, 880.0);
        expect(newState.mode, originalState.mode);
      });

      test('TunerState copyWith preserves unchanged values', () {
        const originalState = TunerState();
        final newState = originalState.copyWith(frequency: 880);

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

    group('Mute trap', () {
      test('startPlaying restores audible volume when muted', () async {
        final notifier = container.read(tunerProvider.notifier);
        await notifier.setMode(TunerMode.generate);
        notifier.setVolume(0);
        expect(container.read(tunerProvider).volume, 0);

        await notifier.startPlaying();
        expect(container.read(tunerProvider).volume, 0.5);
      });
    });

    group('Transposition', () {
      test('defaults to concert pitch (0 semitones)', () {
        expect(container.read(tunerProvider).transpositionSemitones, 0);
      });

      test('setTransposition updates state and clamps to 0-11', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.setTransposition(9);
        expect(container.read(tunerProvider).transpositionSemitones, 9);
        notifier.setTransposition(-3);
        expect(container.read(tunerProvider).transpositionSemitones, 0);
        notifier.setTransposition(15);
        expect(container.read(tunerProvider).transpositionSemitones, 11);
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
        notifier.updateFrequency(880);

        final state = container.read(tunerProvider);
        expect(state.frequency, 880.0);
      });

      test('updateFrequency clamps to minimum 20 Hz', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.updateFrequency(10);

        final state = container.read(tunerProvider);
        expect(state.frequency, 20.0);
      });

      test('updateFrequency clamps to maximum 2000 Hz', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.updateFrequency(3000);

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
        final cents = notifier.calculateCents(440);
        expect(cents, 0);
      });

      test('calculateCents clamps to -50 to 50', () {
        final notifier = container.read(tunerProvider.notifier);

        // Very high frequency should clamp to 50
        final cents = notifier.calculateCents(10000);
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
        const noteData = NoteData(note: 'A', octave: 4, frequency: 440);

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
      test('ProviderContainer dispose cleans up resources', () {
        final localContainer = ProviderContainer();
        localContainer.read(tunerProvider);
        expect(localContainer.dispose, returnsNormally);
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

        notifier.updateFrequency(440);
        expect(container.read(tunerProvider).frequency, 440.0);

        notifier.updateFrequency(880);
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
        notifier.updateFrequency(20);

        final state = container.read(tunerProvider);
        expect(state.frequency, 20.0);
      });

      test('updateFrequency with exactly 2000 Hz', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.updateFrequency(2000);

        final state = container.read(tunerProvider);
        expect(state.frequency, 2000.0);
      });

      test('setVolume with 0.0', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.setVolume(0);

        final state = container.read(tunerProvider);
        expect(state.volume, 0.0);
      });

      test('setVolume with 1.0', () {
        final notifier = container.read(tunerProvider.notifier);
        notifier.setVolume(1);

        final state = container.read(tunerProvider);
        expect(state.volume, 1.0);
      });

      test('calculateCents with standard frequencies', () {
        final notifier = container.read(tunerProvider.notifier);

        // Test various standard frequencies
        expect(notifier.calculateCents(440), inInclusiveRange(-50, 50));
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

        notifier.updateFrequency(880);

        expect(container.read(tunerFrequencyProvider), 880.0);
        expect(container.read(tunerProvider).frequency, 880.0);
      });
    });
  });
}
