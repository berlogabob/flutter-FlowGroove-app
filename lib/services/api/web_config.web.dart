/// Web-specific configuration helper for accessing window.env
/// This file is used only when building for web (dart.library.html)
library;

import 'dart:js_interop';

// External access to window.env object
@JS('window.env.SPOTIFY_CLIENT_ID')
external JSString? get _clientId;

@JS('window.env.SPOTIFY_CLIENT_SECRET')
external JSString? get _clientSecret;

/// Get a value from window.env object
String getWebConfig(String key) {
  try {
    switch (key) {
      case 'SPOTIFY_CLIENT_ID':
        return _clientId?.toDart ?? '';
      case 'SPOTIFY_CLIENT_SECRET':
        return _clientSecret?.toDart ?? '';
      default:
        return '';
    }
  } catch (e) {
    // Web config not available
    return '';
  }
}

/// Check if window.env is available
bool hasWebConfig() {
  try {
    return _clientId != null || _clientSecret != null;
  } catch (e) {
    return false;
  }
}
