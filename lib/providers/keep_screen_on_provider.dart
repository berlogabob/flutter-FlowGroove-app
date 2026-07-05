/// Global "keep screen on" preference.
///
/// Persisted bool (default on) that drives the app-wide wakelock via
/// `WakelockController.setAlwaysOn`. Toggled from the app bar's 3-dots menu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wakelock_provider.dart';

const _keepScreenOnKey = 'app.keep_screen_on';

class KeepScreenOn extends Notifier<bool> {
  @override
  bool build() {
    // Default on; async load reconciles with the stored value + applies it.
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_keepScreenOnKey) ?? true;
    state = value;
    await ref.read(wakelockProvider).setAlwaysOn(value: value);
  }

  Future<void> toggle() async {
    final value = !state;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepScreenOnKey, value);
    await ref.read(wakelockProvider).setAlwaysOn(value: value);
  }
}

final keepScreenOnProvider =
    NotifierProvider<KeepScreenOn, bool>(KeepScreenOn.new);
