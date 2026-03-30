/// Web-specific configuration helper for accessing window.env
/// This file is used only when building for web (dart.library.html)
library;

import 'dart:js_interop';

// External access to window.env object
@JS('window.env')
external JSObject? get _env;

/// Get a value from window.env object
String getWebConfig(String key) {
  try {
    final env = _env;
    if (env == null) return '';
    
    // Dynamic property access
    final value = env[key];
    if (value == null) return '';
    
    return (value as JSString?)?.toDart ?? '';
  } catch (e) {
    // Web config not available
    return '';
  }
}

/// Check if window.env is available
bool hasWebConfig() {
  try {
    return _env != null;
  } catch (e) {
    return false;
  }
}

/// Check if a specific key exists in window.env
bool hasWebConfigKey(String key) {
  try {
    final env = _env;
    if (env == null) return false;
    
    final value = env[key];
    return value != null && (value as JSString?)?.toDart.isNotEmpty == true;
  } catch (e) {
    return false;
  }
}
