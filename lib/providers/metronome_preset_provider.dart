import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/metronome_preset.dart';
import '../repositories/metronome_preset_repository.dart';

final metronomePresetRepositoryProvider = Provider<MetronomePresetRepository>(
  (ref) => MetronomePresetRepository(),
);

class MetronomePresetNotifier extends AsyncNotifier<List<MetronomePreset>> {
  late MetronomePresetRepository _repository;

  @override
  Future<List<MetronomePreset>> build() async {
    _repository = ref.read(metronomePresetRepositoryProvider);
    return _repository.list();
  }

  Future<void> save(MetronomePreset preset) async {
    await _repository.save(preset);
    state = AsyncData(await _repository.list());
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = AsyncData(await _repository.list());
  }
}

final metronomePresetProvider =
    AsyncNotifierProvider<MetronomePresetNotifier, List<MetronomePreset>>(
      MetronomePresetNotifier.new,
    );
