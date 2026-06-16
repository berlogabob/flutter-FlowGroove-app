/// Runtime Configuration Validator
///
/// Validates that all required configuration is present before app startup
/// Shows user-friendly error messages if configuration is missing
library;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart' show debugPrint;
import '../config/env_config.dart';

/// Result of configuration validation
class ConfigValidationResult {
  ConfigValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  @override
  String toString() {
    if (isValid) return 'ConfigValidationResult: Valid';
    return 'ConfigValidationResult: ${errors.length} errors, ${warnings.length} warnings';
  }
}

/// Validates application configuration at runtime
class ConfigValidator {
  /// Validate all required configuration
  ///
  /// Returns [ConfigValidationResult] with validation status
  static Future<ConfigValidationResult> validate() async {
    final errors = <String>[];
    final warnings = <String>[];

    // Check Firebase configuration.
    //
    // On mobile (Android/iOS) the Firebase API key is a non-secret value that is
    // also bundled in google-services.json / GoogleService-Info.plist, and
    // DefaultFirebaseOptions falls back to it. So a missing compile-time define is
    // not fatal there. On web the key must be injected via config.js, so it stays
    // a hard error.
    if (env.firebaseApiKey.isNotEmpty && _isPlaceholder(env.firebaseApiKey)) {
      errors.add('Firebase API key appears to be a placeholder value');
    } else if (env.firebaseApiKey.isEmpty && kIsWeb) {
      errors.add('Firebase API key is not configured');
    }

    // Check Firebase App ID (hardcoded, but verify it's valid format)
    // This is just a sanity check
    const String expectedAppIdPattern = r'^1:\d+:[a-z]+:[a-f0-9]+$';
    const String appId = '1:703941154390:web:43dfeaf2f6a0495e004df7';
    if (!RegExp(expectedAppIdPattern).hasMatch(appId)) {
      errors.add('Firebase App ID format is invalid');
    }

    // Check Spotify configuration (optional, but warn if missing on non-web)
    if (!kIsWeb && !env.isSpotifyConfigured) {
      if (env.spotifyClientId.isEmpty || _isPlaceholder(env.spotifyClientId)) {
        warnings.add('Spotify Client ID is not configured - Spotify features will be disabled');
      }
      if (env.spotifyClientSecret.isEmpty || _isPlaceholder(env.spotifyClientSecret)) {
        warnings.add('Spotify Client Secret is not configured - Spotify features will be disabled');
      }
    }

    // Check if proxy is configured (recommended for production)
    if (!env.useSpotifyProxy && kIsWeb && !kDebugMode) {
      warnings.add(
        'Spotify Proxy URL is not configured. '
        'For production, consider using a backend proxy for Spotify API calls.',
      );
    }

    // Check Twitter configuration (optional)
    if (!kIsWeb && !env.isTwitterConfigured) {
      warnings.add('Twitter/X credentials are not configured - Twitter features will be disabled');
    }

    return ConfigValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate configuration and throw if critical errors found
  ///
  /// This should be called during app initialization
  static Future<void> validateOrThrow() async {
    final result = await validate();
    
    if (!result.isValid) {
      throw ConfigValidationException(
        'Configuration validation failed: ${result.errors.join(', ')}',
        errors: result.errors,
        warnings: result.warnings,
      );
    }

    // Log warnings in debug mode
    if (kDebugMode) {
      for (final warning in result.warnings) {
        debugPrint('⚠️  Config warning: $warning');
      }
    }
  }

  /// Check if a value is a placeholder
  static bool _isPlaceholder(String value) {
    return value.isEmpty ||
           value.contains('REPLACE_ME') ||
           value.contains('your_') ||
           value.contains('YOUR_') ||
           value == 'none';
  }
}

/// Exception thrown when configuration validation fails
class ConfigValidationException implements Exception {
  ConfigValidationException(
    this.message, {
    required this.errors,
    required this.warnings,
  });

  final String message;
  final List<String> errors;
  final List<String> warnings;

  @override
  String toString() => 'ConfigValidationException: $message';
}
