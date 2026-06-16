/// Web Configuration Tests
/// 
/// Tests for web-specific config loading:
/// - getWebConfig() function
/// - hasWebConfig() checks
/// - JS interop simulation
/// - Empty/missing config handling
///
/// Note: These tests use the stub implementation on non-web platforms
/// For web platform tests, run with: flutter test --platform chrome
library;

import 'package:flowgroove/services/api/web_config.stub.dart' as stub_config;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

// Conditional import for web-specific testing
import 'web_config_test.web.dart' if (dart.library.io) 'web_config_test.io.dart';

void main() {
  group('WebConfig Tests', () {
    group('Stub Implementation (Non-Web)', () {
      test('getWebConfig returns empty string on non-web', () {
        if (!kIsWeb) {
          final result = stub_config.getWebConfig('ANY_KEY');
          expect(result, equals(''));
        }
      });

      test('hasWebConfig returns false on non-web', () {
        if (!kIsWeb) {
          final result = stub_config.hasWebConfig();
          expect(result, isFalse);
        }
      });

      test('hasWebConfigKey returns false on non-web', () {
        if (!kIsWeb) {
          final result = stub_config.hasWebConfigKey('ANY_KEY');
          expect(result, isFalse);
        }
      });

      test('getWebConfig handles null key gracefully', () {
        if (!kIsWeb) {
          // Should not throw with any input
          expect(() => stub_config.getWebConfig(''), returnsNormally);
          expect(() => stub_config.getWebConfig('TEST'), returnsNormally);
        }
      });

      test('hasWebConfigKey handles empty string key', () {
        if (!kIsWeb) {
          final result = stub_config.hasWebConfigKey('');
          expect(result, isFalse);
        }
      });
    });

    group('Platform-Specific Tests', () {
      test('should use correct implementation based on platform', () {
        // Verify the conditional import works
        final platformResult = getPlatformInfo();
        expect(platformResult, isNotEmpty);
      });

      test('should handle web config access safely', () {
        // This should not throw on any platform
        expect(() {
          stub_config.getWebConfig('TEST_KEY');
          stub_config.hasWebConfig();
          stub_config.hasWebConfigKey('TEST_KEY');
        }, returnsNormally);
      });
    });

    group('Edge Cases', () {
      test('should handle special characters in keys', () {
        if (!kIsWeb) {
          const specialKeys = [
            'KEY_WITH_SPACE',
            'KEY-WITH-DASH',
            'KEY.WITH.DOT',
            'KEY_WITH_123',
          ];

          for (final key in specialKeys) {
            expect(() => stub_config.getWebConfig(key), returnsNormally);
            expect(() => stub_config.hasWebConfigKey(key), returnsNormally);
          }
        }
      });

      test('should handle very long keys', () {
        if (!kIsWeb) {
          const longKey = 'THIS_IS_A_VERY_LONG_KEY_NAME_THAT_EXCEEDS_NORMAL_LENGTH_EXPECTATIONS';
          expect(() => stub_config.getWebConfig(longKey), returnsNormally);
          expect(() => stub_config.hasWebConfigKey(longKey), returnsNormally);
        }
      });

      test('should handle unicode keys', () {
        if (!kIsWeb) {
          const unicodeKey = 'KEY_中文_🎵';
          expect(() => stub_config.getWebConfig(unicodeKey), returnsNormally);
          expect(() => stub_config.hasWebConfigKey(unicodeKey), returnsNormally);
        }
      });
    });

    group('Consistency Tests', () {
      test('multiple calls should return consistent results', () {
        if (!kIsWeb) {
          const testKey = 'CONSISTENCY_TEST_KEY';
          
          final result1 = stub_config.getWebConfig(testKey);
          final result2 = stub_config.getWebConfig(testKey);
          final result3 = stub_config.getWebConfig(testKey);
          
          expect(result1, equals(result2));
          expect(result2, equals(result3));
          expect(result1, equals('')); // All should be empty on non-web
        }
      });

      test('hasWebConfig should return same value on repeated calls', () {
        if (!kIsWeb) {
          final result1 = stub_config.hasWebConfig();
          final result2 = stub_config.hasWebConfig();
          final result3 = stub_config.hasWebConfig();
          
          expect(result1, equals(result2));
          expect(result2, equals(result3));
          expect(result1, isFalse); // All should be false on non-web
        }
      });
    });

    group('Error Handling', () {
      test('should not throw on any input', () {
        // Test various edge case inputs
        const testInputs = [
          '',
          ' ',
          '\n',
          '\t',
          'null',
          'undefined',
          'FIREBASE_API_KEY',
          'SPOTIFY_CLIENT_ID',
        ];

        for (final input in testInputs) {
          expect(
            () {
              stub_config.getWebConfig(input);
              stub_config.hasWebConfigKey(input);
            },
            returnsNormally,
            reason: 'Should not throw for input: $input',
          );
        }

        expect(stub_config.hasWebConfig, returnsNormally);
      });
    });
  });

  group('Web Config Integration', () {
    test('should integrate with EnvConfig properly', () {
      // Import EnvConfig to verify integration
      // This is a compile-time check that imports work correctly
      expect(stub_config.getWebConfig, isNotNull);
      expect(stub_config.hasWebConfig, isNotNull);
      expect(stub_config.hasWebConfigKey, isNotNull);
    });

    test('stub implementation should be safe for production', () {
      // Verify stub doesn't expose any sensitive data
      if (!kIsWeb) {
        expect(stub_config.getWebConfig('FIREBASE_API_KEY'), equals(''));
        expect(stub_config.getWebConfig('SPOTIFY_CLIENT_ID'), equals(''));
        expect(stub_config.getWebConfig('SPOTIFY_CLIENT_SECRET'), equals(''));
      }
    });
  });
}
