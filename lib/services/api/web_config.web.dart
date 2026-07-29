/// Web-specific configuration helper for accessing window.env
/// This file is used only when building for web (dart.library.html)
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _env {
  final env = globalContext.getProperty('env'.toJS);
  if (env.isUndefinedOrNull || !env.isA<JSObject>()) return null;
  return env as JSObject;
}

/// Get a value from window.env object
String getWebConfig(String key) {
  try {
    final value = _env?.getProperty(key.toJS);
    if (value == null || value.isUndefinedOrNull) return '';
    return value.dartify()?.toString() ?? '';
  } catch (e) {
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
    return getWebConfig(key).isNotEmpty;
  } catch (e) {
    return false;
  }
}
