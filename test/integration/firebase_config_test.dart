/// Integration Tests for Firebase Configuration
///
/// Current contract (see lib/firebase_options.dart, lib/config/config_validator.dart):
/// - Web: the API key must come from EnvConfig (config.js / dart-define);
///   an empty or placeholder key throws StateError.
/// - Android/iOS: the key falls back to the value bundled in
///   google-services.json / GoogleService-Info.plist, so options always
///   resolve even without a compile-time define.
/// - ConfigValidator: missing key is a hard error only on web; on other
///   platforms (incl. the test VM) it validates with warnings for optional
///   features (Spotify, Twitter).
library;

import 'package:flowgroove/config/config_validator.dart';
import 'package:flowgroove/config/env_config.dart';
import 'package:flowgroove/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Configuration Integration Tests', () {
    group('DefaultFirebaseOptions', () {
      group('Web Platform', () {
        test('should throw StateError when Firebase API key is empty', () {
          // EnvConfig returns empty string in the test environment
          expect(
            () => DefaultFirebaseOptions.web,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Firebase API key not configured'),
              ),
            ),
          );
        });

        test('error should mention FIREBASE_API_KEY variable name', () {
          expect(
            () => DefaultFirebaseOptions.web,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('FIREBASE_API_KEY'),
              ),
            ),
          );
        });
      });

      group('Android Platform', () {
        test('options resolve via bundled fallback key', () {
          final options = DefaultFirebaseOptions.android;
          expect(options.apiKey, isNotEmpty);
          expect(options.appId, contains(':android:'));
        });

        test('android options should include required fields', () {
          final options = DefaultFirebaseOptions.android;
          expect(options.projectId, contains('repsync'));
          expect(options.messagingSenderId, isNotEmpty);
          expect(options.storageBucket, isNotEmpty);
        });
      });

      group('iOS Platform', () {
        test('options resolve via bundled fallback key', () {
          final options = DefaultFirebaseOptions.ios;
          expect(options.apiKey, isNotEmpty);
          expect(options.appId, contains(':ios:'));
        });

        test('ios options should include bundle ID', () {
          final options = DefaultFirebaseOptions.ios;
          expect(options.iosBundleId, 'com.flowgroove.app');
        });
      });

      group('Platform Detection', () {
        test('currentPlatform should handle platform detection', () {
          // On the VM (test environment) this throws UnsupportedError;
          // on actual platforms it returns options.
          try {
            final options = DefaultFirebaseOptions.currentPlatform;
            expect(options, isNotNull);
          } on UnsupportedError {
            // Expected in test environment
          }
        });
      });
    });

    group('ConfigValidator', () {
      group('validate() method', () {
        test('missing key is not fatal off-web (mobile fallback exists)',
            () async {
          final result = await ConfigValidator.validate();

          expect(result.isValid, isTrue);
          expect(result.errors, isEmpty);
        });

        test('should return warnings for optional features', () async {
          final result = await ConfigValidator.validate();

          expect(result.warnings, isNotEmpty);
          final warningText = result.warnings.join(' ');
          expect(
            warningText,
            anyOf(
              contains('Spotify'),
              contains('Twitter'),
              contains('Track Analysis'),
            ),
          );
        });

        test('result structure is complete', () async {
          final result = await ConfigValidator.validate();

          expect(result, isNotNull);
          expect(result.errors, isNotNull);
          expect(result.warnings, isNotNull);
          expect(result.isValid, isNotNull);
        });
      });

      group('validateOrThrow() method', () {
        test('completes normally when config is valid', () async {
          await expectLater(ConfigValidator.validateOrThrow(), completes);
        });
      });
    });

    group('Integration with EnvConfig', () {
      test('EnvConfig singleton should be accessible', () {
        final config = EnvConfig();
        expect(config, isNotNull);
      });

      test('EnvConfig should provide firebaseApiKey getter', () {
        final config = EnvConfig();
        expect(() => config.firebaseApiKey, returnsNormally);
      });

      test('firebaseApiKey is empty in the test environment', () {
        final config = EnvConfig();
        expect(config.firebaseApiKey.isEmpty, isTrue);
      });
    });

    group('Error Messages', () {
      test('web error should mention config file location', () {
        try {
          DefaultFirebaseOptions.web;
          fail('Expected StateError');
        } on StateError catch (e) {
          expect(
            e.message.toLowerCase(),
            anyOf(
              contains('config.js'),
              contains('.env'),
              contains('firebase_api_key'),
            ),
          );
        }
      });
    });
  });
}
