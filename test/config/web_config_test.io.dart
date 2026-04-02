/// IO-specific test helpers for web_config_test.dart
/// This file is used only when testing on non-web platforms
library;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Get platform information for testing
String getPlatformInfo() {
  if (kIsWeb) {
    return 'web';
  }
  return 'io';
}
