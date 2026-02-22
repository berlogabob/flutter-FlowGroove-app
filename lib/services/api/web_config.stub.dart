/// Stub configuration helper for non-web platforms
/// This file is used when NOT building for web
library;

/// Get a value from window.env object (stub - always returns empty string)
String getWebConfig(String key) {
  // Not available on non-web platforms
  return '';
}

/// Check if window.env is available (stub - always returns false)
bool hasWebConfig() {
  return false;
}
