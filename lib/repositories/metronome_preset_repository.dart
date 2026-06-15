import 'package:hive/hive.dart';

import '../models/metronome_preset.dart';
import '../models/metronome_tempo_range.dart';

class MetronomePresetRepository {
  static const String boxName = 'metronome_presets_v1';

  Future<Box<dynamic>> get _box => Hive.openBox<dynamic>(boxName);

  Future<List<MetronomePreset>> list() async {
    final box = await _box;
    final presets = box.values
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (value) => MetronomePreset.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList();
    presets.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return presets;
  }

  Future<MetronomePreset?> load(String id) async {
    final value = (await _box).get(id);
    if (value is! Map) return null;
    return MetronomePreset.fromJson(Map<String, dynamic>.from(value));
  }

  Future<void> save(MetronomePreset preset) async {
    _validate(preset);
    await (await _box).put(preset.id, preset.toJson());
  }

  Future<void> delete(String id) async => (await _box).delete(id);

  void _validate(MetronomePreset preset) {
    if (preset.id.isEmpty) throw ArgumentError('Preset id must not be empty');
    if (preset.name.trim().isEmpty) {
      throw ArgumentError('Preset name must not be empty');
    }
    if (!MetronomeTempoRange.contains(preset.bpm)) {
      throw ArgumentError(
        'Preset BPM must be within ${MetronomeTempoRange.label}',
      );
    }
    if (preset.subdivisions < 1 || preset.subdivisions > 12) {
      throw ArgumentError('Preset subdivisions must be between 1 and 12');
    }
    if (preset.volume < 0 || preset.volume > 1) {
      throw ArgumentError('Preset volume must be between 0 and 1');
    }
  }
}
