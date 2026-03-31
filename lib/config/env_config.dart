import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Secure Environment Config Loader
/// 
/// This provides a unified way to load environment variables across platforms:
/// - **Web**: Uses window.env (injected at runtime via config.js)
/// - **Mobile/Desktop**: Uses flutter_dotenv with .env file
/// 
/// SECURITY:
/// - assets/env.json is NOT bundled in web builds (removed from pubspec.yaml)
/// - For web, use config.js injected at deployment time
/// - For mobile, keep .env file in .gitignore
/// 
/// Setup Instructions:
/// 1. Copy assets/env.json.template to assets/env.json (mobile only)
/// 2. Copy web/config.js.template to web/config.js and fill in values
/// 3. NEVER commit env.json or config.js to git!
class EnvConfig {
  static final EnvConfig _instance = EnvConfig._internal();
  factory EnvConfig() => _instance;
  EnvConfig._internal();

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
        // Web config not available, continue to fallback
      }

      // Fallback to dotenv (if somehow loaded)
      try {
        final fromDotenv = dotenv.env[key] ?? '';
        if (fromDotenv.isNotEmpty && !_isPlaceholder(fromDotenv)) {
          return fromDotenv;
        }
      } catch (e) {
        // dotenv not initialized yet
      }
    } else {
      // Mobile/Desktop: Use dotenv
      try {
        final value = dotenv.env[key] ?? '';
        if (value.isNotEmpty && !_isPlaceholder(value)) {
          return value;
        }
      } catch (e) {
        // dotenv not initialized yet - this happens during Firebase initialization
        // Return default value to prevent crash
      }
    }

    return defaultValue;
  }

  /// Get Firebase API Key
  String get firebaseApiKey => get('FIREBASE_API_KEY');

  /// Get Spotify Client ID
  String get spotifyClientId => get('SPOTIFY_CLIENT_ID');

  /// Get Spotify Client Secret
  String get spotifyClientSecret => get('SPOTIFY_CLIENT_SECRET');

  /// Get Twitter API Key
  String get twitterApiKey => get('TWITTER_API_KEY');

  /// Get Twitter API Secret
  String get twitterApiSecret => get('TWITTER_API_SECRET');

  /// Get Track Analysis API Key (RapidAPI)
  String get trackAnalysisApiKey => get('TRACK_ANALYSIS_API_KEY');

  /// Get Telegram Bot Token
  String get telegramBotToken => get('TELEGRAM_BOT_TOKEN');

  /// Get Spotify Proxy URL
  String get spotifyProxyUrlConfig => get('SPOTIFY_PROXY_URL');

  /// Check if Spotify credentials are configured
  bool get isSpotifyConfigured {
    return spotifyClientId.isNotEmpty && 
           spotifyClientSecret.isNotEmpty &&
           !_isPlaceholder(spotifyClientId) &&
           !_isPlaceholder(spotifyClientSecret);
  }

  /// Check if Twitter credentials are configured
  bool get isTwitterConfigured {
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
    // This uses JS interop - implemented in web_config.web.dart
    // Stub implementation returns empty string for non-web
    return '';
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
