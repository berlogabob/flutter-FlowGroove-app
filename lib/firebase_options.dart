// lib/firebase_options.dart
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'config/env_config.dart';

class DefaultFirebaseOptions {
  /// Public Firebase API key for the Android/iOS apps.
  ///
  /// This is NOT a secret: the same value already ships inside
  /// `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`,
  /// and would be present in any released binary. Firebase API keys identify the
  /// project; access is enforced by Firestore Security Rules + App Check, not by
  /// hiding the key. Used as a fallback so the app boots in every build mode even
  /// when no compile-time `--dart-define=FIREBASE_API_KEY` is supplied.
  static const String _mobileFallbackApiKey =
      'AIzaSyBBmMazakzn-C6eveJdMyhUpeJWYcLowjk';

  /// Resolves the effective Firebase API key for mobile: prefers an explicit
  /// compile-time/runtime value, otherwise falls back to the bundled public key.
  static String get _mobileApiKey {
    final fromEnv = env.firebaseApiKey;
    if (fromEnv.isNotEmpty && !_isPlaceholder(fromEnv)) {
      return fromEnv;
    }
    return _mobileFallbackApiKey;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    } else if (Platform.isAndroid) {
      return android;
    } else if (Platform.isIOS) {
      return ios;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static FirebaseOptions get web {
    final apiKey = env.firebaseApiKey;
    if (apiKey.isEmpty || _isPlaceholder(apiKey)) {
      throw StateError(
        'Firebase API key not configured. '
        'Check web/config.js or .env file. '
        'The FIREBASE_API_KEY must be set to a valid value.',
      );
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: '1:703941154390:web:43dfeaf2f6a0495e004df7',
      messagingSenderId: '703941154390',
      projectId: 'repsync-app-8685c',
      authDomain: 'repsync-app-8685c.firebaseapp.com',
      storageBucket: 'repsync-app-8685c.firebasestorage.app',
      measurementId: 'G-T6YBX0M53W', // flowgroove.app stream - used for all deployments
    );
  }

  static FirebaseOptions get android {
    return FirebaseOptions(
      apiKey: _mobileApiKey,
      appId: '1:703941154390:android:452fa16f90a8ec3d004df7',
      messagingSenderId: '703941154390',
      projectId: 'repsync-app-8685c',
      authDomain: 'repsync-app-8685c.firebaseapp.com',
      storageBucket: 'repsync-app-8685c.firebasestorage.app',
    );
  }

  static FirebaseOptions get ios {
    return FirebaseOptions(
      apiKey: _mobileApiKey,
      appId: '1:703941154390:ios:43dfeaf2f6a0495e004df7',
      messagingSenderId: '703941154390',
      projectId: 'repsync-app-8685c',
      authDomain: 'repsync-app-8685c.firebaseapp.com',
      storageBucket: 'repsync-app-8685c.firebasestorage.app',
      iosBundleId: 'com.flowgroove.app',
    );
  }

  // Helper: Check if value is a placeholder (REPLACE_ME_*, your_*, etc.)
  static bool _isPlaceholder(String value) {
    return value.isEmpty ||
           value.contains('REPLACE_ME') ||
           value.contains('your_') ||
           value.contains('YOUR_') ||
           value == 'none';
  }
}
