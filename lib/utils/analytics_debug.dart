// Debug utility for Firebase Analytics
// Add this to test analytics events

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsDebug {
  static FirebaseAnalytics? _analyticsInstance;
  static bool _debugMode = true;

  static FirebaseAnalytics? get _analytics {
    try {
      _analyticsInstance ??= FirebaseAnalytics.instance;
      return _analyticsInstance;
    } catch (_) {
      return null; // Firebase not initialized (test environment)
    }
  }

  /// Enable debug mode - logs all events to console
  static void enableDebugMode() {
    _debugMode = true;
    debugPrint('📊 Analytics Debug Mode: ENABLED');
  }

  /// Disable debug mode
  static void disableDebugMode() {
    _debugMode = false;
  }

  /// Test analytics connection
  static Future<void> testConnection() async {
    debugPrint('🔍 Testing Firebase Analytics Connection...');

    try {
      final analytics = _analytics;
      if (analytics == null) {
        debugPrint('❌ Analytics not initialized');
        return;
      }

      // Check if analytics is initialized
      debugPrint('✅ Analytics instance created');

      // Enable collection
      await analytics.setAnalyticsCollectionEnabled(true);
      debugPrint('✅ Analytics collection enabled');

      // Set debug mode (not supported on Web)
      if (!kIsWeb) {
        await analytics.setSessionTimeoutDuration(const Duration(seconds: 30));
        debugPrint('✅ Session timeout set to 30 seconds');
      } else {
        debugPrint('🌐 Web platform - session timeout not available');
      }

      // Log test event
      await analytics.logEvent(
        name: 'analytics_test',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': kIsWeb ? 'web' : 'mobile',
          'test': 'true',
        },
      );
      debugPrint('✅ Test event logged: analytics_test');

      // Get app instance ID (not available on Web)
      if (!kIsWeb) {
        final appId = await analytics.appInstanceId;
        debugPrint('📱 App Instance ID: $appId');
      }

      debugPrint('');
      debugPrint('🎉 Analytics Test COMPLETE');
      debugPrint('');
      debugPrint('📊 Check events at:');
      debugPrint('   https://console.firebase.google.com/project/repsync-app-8685c/analytics/debugview');
      debugPrint('');
      if (!kIsWeb) {
        debugPrint('⏱️  Realtime updates every 30 seconds');
      } else {
        debugPrint('⏱️  Web analytics may take 24-48 hours to appear in dashboard');
      }

    } catch (e, stack) {
      debugPrint('❌ Analytics Test FAILED');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stack');
    }
  }

  /// Log screen view with debug output
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );

    if (_debugMode) {
      debugPrint('📊 Screen View: $screenName (${screenClass ?? "unknown"})');
    }
  }

  /// Log event with debug output
  static Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
      name: name,
      parameters: parameters?.cast<String, Object>(),
    );

    if (_debugMode) {
      debugPrint('📊 Event: $name');
      if (parameters != null && parameters.isNotEmpty) {
        debugPrint('   Parameters: $parameters');
      }
    }
  }

  /// Log login event
  static Future<void> logLogin({
    String? loginMethod,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logLogin(loginMethod: loginMethod ?? 'unknown');

    if (_debugMode) {
      debugPrint('📊 Login: $loginMethod');
    }
  }

  /// Log app open
  static Future<void> logAppOpen() async {
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logAppOpen();

    if (_debugMode) {
      debugPrint('📊 App Open');
    }
  }
}
