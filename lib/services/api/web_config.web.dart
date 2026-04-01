/// Web-specific configuration helper for accessing window.env
/// This file is used only when building for web (dart.library.html)
library;

// Note: dart:js is used for web compatibility
// ignore: deprecated_member_use
import 'dart:js' as js;

/// Get a value from window.env object
String getWebConfig(String key) {
  try {
    final env = js.context['window']['env'];
    if (env == null) return '';

    final value = env[key];
    if (value == null) return '';

    return value.toString();
  } catch (e) {
    // Web config not available
    return '';
  }
}

/// Check if window.env is available
bool hasWebConfig() {
  try {
    final env = js.context['window']['env'];
    return env != null;
  } catch (e) {
    return false;
  }
}

/// Check if a specific key exists in window.env
bool hasWebConfigKey(String key) {
  try {
    final env = js.context['window']['env'];
    if (env == null) return false;

    final value = env[key];
    return value != null && value.toString().isNotEmpty;
  } catch (e) {
    return false;
  }
}
