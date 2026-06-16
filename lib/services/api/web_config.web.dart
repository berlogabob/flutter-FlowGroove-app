/// Web-specific configuration helper for accessing window.env
/// This file is used only when building for web (dart.library.html)
library;

import 'dart:js' as js;

/// Get a value from window.env object
String getWebConfig(String key) {
  try {
    final windowObj = js.context;
    final env = windowObj['env'];
    if (env == null) {
      return '';
    }

    final value = env[key];
    if (value == null) {
      return '';
    }
    return value.toString();
  } catch (e) {
    return '';
  }
}

/// Check if window.env is available
bool hasWebConfig() {
  try {
    final env = js.context['env'];
    return env != null;
  } catch (e) {
    return false;
  }
}

/// Check if a specific key exists in window.env
bool hasWebConfigKey(String key) {
  try {
    final env = js.context['env'];
    if (env == null) return false;

    final value = env[key];
    return value != null && value.toString().isNotEmpty;
  } catch (e) {
    return false;
  }
}
