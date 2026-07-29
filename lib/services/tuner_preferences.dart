import 'package:shared_preferences/shared_preferences.dart';

class TunerPreferences {
  static const _modeKey = 'tuner.mode';
  static const _referenceKey = 'tuner.reference_hz';
  static const _volumeKey = 'tuner.volume';
  static const _toleranceKey = 'tuner.cents_tolerance';
  static const _sensitivityKey = 'tuner.input_sensitivity';
  static const _presetKey = 'tuner.last_preset_id';
  static const _recentPresetKey = 'tuner.recent_preset_ids';
  static const _droneKey = 'tuner.drone_enabled';
  static const _transpositionKey = 'tuner.transposition';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<Map<String, Object?>> load() async {
    final preferences = await _preferences;
    return <String, Object?>{
      'mode': preferences.getString(_modeKey),
      'referenceHz': preferences.getDouble(_referenceKey),
      'volume': preferences.getDouble(_volumeKey),
      'centsTolerance': preferences.getInt(_toleranceKey),
      'sensitivity': preferences.getDouble(_sensitivityKey),
      'presetId': preferences.getString(_presetKey),
      'recentPresetIds': preferences.getStringList(_recentPresetKey),
      'droneEnabled': preferences.getBool(_droneKey),
      'transposition': preferences.getInt(_transpositionKey),
    };
  }

  Future<void> saveMode(String value) async {
    await _ignoreUnavailable(() async {
      await (await _preferences).setString(_modeKey, value);
    });
  }

  Future<void> saveReferenceHz(double value) async {
    await _ignoreUnavailable(() async {
      await (await _preferences).setDouble(_referenceKey, value);
    });
  }

  Future<void> saveVolume(double value) async {
    await _ignoreUnavailable(() async {
      await (await _preferences).setDouble(_volumeKey, value);
    });
  }

  Future<void> saveTolerance(int value) async {
    await _ignoreUnavailable(() async {
      await (await _preferences).setInt(_toleranceKey, value);
    });
  }

  Future<void> saveSensitivity(double value) async {
    await _ignoreUnavailable(() async {
      await (await _preferences).setDouble(_sensitivityKey, value);
    });
  }

  Future<void> saveTransposition(int value) async {
    await _ignoreUnavailable(() async {
      await (await _preferences).setInt(_transpositionKey, value);
    });
  }

  Future<void> saveDroneEnabled({required bool value}) async {
    await _ignoreUnavailable(() async {
      await (await _preferences).setBool(_droneKey, value);
    });
  }

  Future<void> saveSelectedPreset(String id) async {
    await _ignoreUnavailable(() async {
      final preferences = await _preferences;
      await preferences.setString(_presetKey, id);
      final recent = preferences.getStringList(_recentPresetKey) ?? <String>[];
      recent.remove(id);
      recent.insert(0, id);
      if (recent.length > 10) recent.removeRange(10, recent.length);
      await preferences.setStringList(_recentPresetKey, recent);
    });
  }

  Future<void> _ignoreUnavailable(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Preferences can be unavailable in pure Dart tests and early startup.
    }
  }
}
