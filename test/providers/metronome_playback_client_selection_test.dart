import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/providers/metronome_runtime_providers.dart';

void main() {
  group('useNativeAndroidPlayback', () {
    test('true on Android (non-web) — uses the native foreground service', () {
      expect(
        useNativeAndroidPlayback(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
    });

    test('false on iOS — keeps the unified engine', () {
      expect(
        useNativeAndroidPlayback(isWeb: false, platform: TargetPlatform.iOS),
        isFalse,
      );
    });

    test('false on web even if platform reports android', () {
      expect(
        useNativeAndroidPlayback(isWeb: true, platform: TargetPlatform.android),
        isFalse,
      );
    });
  });
}
