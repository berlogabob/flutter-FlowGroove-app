/// Web-specific configuration helper for accessing window.env
/// This file is used only when building for web (dart.library.html)
library;

import 'dart:js' as js;

/// Get a value from window.env object
String getWebConfig(String key) {
  try {
    // Access window.env using dart:js
    final windowObj = js.context;
    
    final env = windowObj['env'];
    if (env == null) {
      print('❌ window.env is null');
      return '';
    }
    
    final value = env[key];
    if (value == null) {
      print('⚠️  window.env.$key is null');
      return '';
    }
    
    final result = value.toString();
    if (result.isNotEmpty) {
      print('✅ getWebConfig($key) = ${result.substring(0, 10)}...');
    }
    return result;
  } catch (e) {
    print('❌ Error reading window.env.$key: $e');
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
