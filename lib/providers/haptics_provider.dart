/// Global haptics preference (#129) — the single source of truth for
/// vibration feedback app-wide. The metronome's Sound-sheet toggle binds to
/// this provider; the metronome engine state follows it.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hapticsKey = 'app.haptics';

class HapticsEnabled extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  /// Prefs may be unavailable (pure-Dart tests, startup races) — the
  /// preference then simply isn't persisted for this session.
  Future<SharedPreferences?> get _prefs async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final prefs = await _prefs;
    if (prefs == null) return;
    var value = prefs.getBool(_hapticsKey);
    if (value == null) {
      // One-time migration: haptics used to live inside the metronome's
      // persisted manual-settings blob.
      final blob = prefs.getString('metronome.last_manual_settings');
      if (blob != null) {
        try {
          value =
              (json.decode(blob) as Map<String, dynamic>)['hapticsEnabled']
                  as bool?;
        } catch (_) {}
      }
      value ??= true;
      await prefs.setBool(_hapticsKey, value);
    }
    state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await (await _prefs)?.setBool(_hapticsKey, value);
  }

  Future<void> toggle() => set(!state);
}

final hapticsEnabledProvider =
    NotifierProvider<HapticsEnabled, bool>(HapticsEnabled.new);
