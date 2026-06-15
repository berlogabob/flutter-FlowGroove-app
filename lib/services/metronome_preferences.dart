import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MetronomePreferences {
  static const _presetKey = 'metronome.last_preset_id';
  static const _settingsKey = 'metronome.last_manual_settings';
  static const _engineKey = 'metronome.engine_mode';
  static bool storageReady = false;

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<String?> loadLastPresetId() async =>
      (await _preferences).getString(_presetKey);

  Future<void> saveLastPresetId(String? id) async {
    final preferences = await _preferences;
    if (id == null) {
      await preferences.remove(_presetKey);
    } else {
      await preferences.setString(_presetKey, id);
    }
  }

  Future<Map<String, dynamic>?> loadManualSettings() async {
    final value = (await _preferences).getString(_settingsKey);
    if (value == null) return null;
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<void> saveManualSettings(Map<String, dynamic> settings) async {
    await (await _preferences).setString(_settingsKey, jsonEncode(settings));
  }

  Future<String?> loadEngineMode() async =>
      (await _preferences).getString(_engineKey);

  Future<void> saveEngineMode(String mode) async {
    await (await _preferences).setString(_engineKey, mode);
  }
}
