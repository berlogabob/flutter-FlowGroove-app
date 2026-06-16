import 'package:flowgroove/models/tuner_preset.dart';
import 'package:flowgroove/repositories/tuner_preset_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerPresetRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = TunerPresetRepository();
  });

  TunerPreset preset({String name = 'Drop C', int tolerance = 5}) {
    final now = DateTime.utc(2026, 6, 13);
    return TunerPreset(
      id: 'preset-1',
      name: name,
      instrumentType: InstrumentType.guitar,
      tuningNotes: const [
        TuningNote(
          note: 'C',
          octave: 2,
          targetFrequencyHz: 65.406,
          stringNumber: 1,
        ),
      ],
      centsTolerance: tolerance,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('saves, updates, and deletes a local preset', () async {
    await repository.save(preset());
    var loaded = await repository.loadLocal();

    expect(loaded, hasLength(1));
    expect(loaded.single.name, 'Drop C');
    expect(loaded.single.tuningNotes.single.displayName, 'C2');

    await repository.save(preset(name: 'Drop C Live', tolerance: 7));
    loaded = await repository.loadLocal();

    expect(loaded, hasLength(1));
    expect(loaded.single.name, 'Drop C Live');
    expect(loaded.single.centsTolerance, 7);

    await repository.delete(loaded.single);
    expect(await repository.loadLocal(), isEmpty);
  });

  test('rejects invalid calibration and incomplete scopes', () async {
    final invalidReference = preset().copyWith(referenceHz: 500);
    final bandWithoutId = preset().copyWith(scope: TunerPresetScope.band);

    await expectLater(
      repository.save(invalidReference),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      repository.save(bandWithoutId),
      throwsA(isA<ArgumentError>()),
    );
  });
}
