/// Global theme preference (#129): system / dark / light. Default dark —
/// the app's native look. Light is beta: Material surfaces flip, but
/// custom widgets that hardcode MonoPulseColors stay dark-toned until the
/// palette migration (follow-up issue).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app.theme_mode';

class AppThemeMode extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.dark;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_themeModeKey);
    state = ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<AppThemeMode, ThemeMode>(AppThemeMode.new);
