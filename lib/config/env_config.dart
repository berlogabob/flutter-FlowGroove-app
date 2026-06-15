import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api/web_config.stub.dart'
  if (dart.library.html) '../services/api/web_config.web.dart';

/// Secure Environment Config Loader
///
/// This provides a unified way to load environment variables across platforms:
/// - **Web**: Uses public-only window.env (injected at runtime via config.js)
/// - **Android/iOS/Desktop**: Uses compile-time dart-defines
///
/// SECURITY:
/// - assets/env.json is retired as an app runtime source
/// - For web, use config.js injected at deployment time
/// - For non-web, pass values via flutter --dart-define / --dart-define-from-file
///
/// Setup Instructions:
/// 1. Generate web/config.js from web/config.template.js for web deploys
/// 2. Pass FIREBASE_API_KEY via dart-defines for non-web builds
/// 3. NEVER commit generated config.js or secret-bearing local env files
class EnvConfig {
  factory EnvConfig() => _instance;

  EnvConfig._internal();

  static final EnvConfig _instance = EnvConfig._internal();

  /// Get an environment variable by key
  /// Returns empty string if not found
  String get(String key, {String defaultValue = ''}) {
    if (kIsWeb) {
      // Web: Try window.env first (injected at runtime)
      try {
        final fromWeb = _getFromWebConfig(key);
        if (fromWeb.isNotEmpty && !_isPlaceholder(fromWeb)) {
          return fromWeb;
        }
      } catch (e) {
        // Web config not available
      }
    } else {
      final fromDartDefine = _getFromDartDefine(key);
      if (fromDartDefine.isNotEmpty && !_isPlaceholder(fromDartDefine)) {
        return fromDartDefine;
      }
    }

    return defaultValue;
  }

  /// Get Firebase API Key
  String get firebaseApiKey => get('FIREBASE_API_KEY');

  /// Get Spotify Client ID for direct non-web calls only.
  String get spotifyClientId => _getClientSecret('SPOTIFY_CLIENT_ID');

  /// Get Spotify Client Secret for direct non-web calls only.
  String get spotifyClientSecret => _getClientSecret('SPOTIFY_CLIENT_SECRET');

  /// Get Twitter API Key for non-web use only.
  String get twitterApiKey => _getClientSecret('TWITTER_API_KEY');

  /// Get Twitter API Secret for non-web use only.
  String get twitterApiSecret => _getClientSecret('TWITTER_API_SECRET');

  /// Track analysis is disabled on the client until it moves behind a backend.
  String get trackAnalysisApiKey => '';

  /// Get Telegram Bot Token for non-web/backend migration only.
  String get telegramBotToken => _getClientSecret('TELEGRAM_BOT_TOKEN');

  /// Get Spotify Proxy URL
  String get spotifyProxyUrlConfig => get('SPOTIFY_PROXY_URL');

  /// Check if Spotify credentials are configured
  bool get isSpotifyConfigured {
    if (kIsWeb) {
      return useSpotifyProxy;
    }
    return spotifyClientId.isNotEmpty &&
           spotifyClientSecret.isNotEmpty &&
           !_isPlaceholder(spotifyClientId) &&
           !_isPlaceholder(spotifyClientSecret);
  }

  /// Check if Twitter credentials are configured
  bool get isTwitterConfigured {
    if (kIsWeb) {
      return false;
    }
    return twitterApiKey.isNotEmpty &&
           twitterApiSecret.isNotEmpty &&
           !_isPlaceholder(twitterApiKey) &&
           !_isPlaceholder(twitterApiSecret);
  }

  /// Check if Firebase is configured
  bool get isFirebaseConfigured {
    return firebaseApiKey.isNotEmpty && !_isPlaceholder(firebaseApiKey);
  }

  /// Get Spotify Proxy URL if configured
  String? get spotifyProxyUrl {
    final url = spotifyProxyUrlConfig;
    if (url.isNotEmpty && !_isPlaceholder(url)) {
      return url;
    }
    return null;
  }

  /// Check if should use proxy for Spotify API
  bool get useSpotifyProxy => spotifyProxyUrl != null;

  // Helper: Get value from window.env (web only)
  String _getFromWebConfig(String key) {
    if (kIsWeb) {
      // Actually call the web implementation to read window.env
      return getWebConfig(key);
    }
    return '';
  }

  // Helper: Get value from compile-time dart-defines (non-web only).
  String _getFromDartDefine(String key) {
    switch (key) {
      case 'FIREBASE_API_KEY':
        return const String.fromEnvironment('FIREBASE_API_KEY');
      case 'SPOTIFY_CLIENT_ID':
        return String.fromEnvironment('SPOTIFY_CLIENT_ID');
      case 'SPOTIFY_CLIENT_SECRET':
        return String.fromEnvironment('SPOTIFY_CLIENT_SECRET');
      case 'TWITTER_API_KEY':
        return String.fromEnvironment('TWITTER_API_KEY');
      case 'TWITTER_API_SECRET':
        return String.fromEnvironment('TWITTER_API_SECRET');
      case 'TELEGRAM_BOT_TOKEN':
        return String.fromEnvironment('TELEGRAM_BOT_TOKEN');
      case 'SPOTIFY_PROXY_URL':
        return String.fromEnvironment('SPOTIFY_PROXY_URL');
      default:
        return '';
    }
  }

  // Helper: client secrets must never come from the web runtime config.
  String _getClientSecret(String key) {
    if (kIsWeb) {
      return '';
    }
    return get(key);
  }

  // Helper: Check if value is a placeholder
  bool _isPlaceholder(String value) {
    return value.isEmpty ||
           value.contains('REPLACE_ME') ||
           value.contains('your_') ||
           value.contains('YOUR_') ||
           value == 'none';
  }
}

// Global instance for easy access
final env = EnvConfig();
