/// Global "share usage analytics" preference.
///
/// Persisted bool (default on) that drives `AnalyticsService.enabled`.
/// Toggled from the Profile screen. Mirrors `keepScreenOnProvider`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';

const _analyticsConsentKey = 'app.analytics_consent';

class AnalyticsConsent extends Notifier<bool> {
  @override
  bool build() {
    // Default on; async load reconciles with the stored value + applies it.
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_analyticsConsentKey) ?? true;
    state = value;
    AnalyticsService.enabled = value;
    // The Dart flag only covers the [_log] events; this stops the legacy
    // methods and Firebase's automatic events too.
    await AnalyticsService.setAnalyticsCollectionEnabled(value);
  }

  Future<void> toggle() async {
    final value = !state;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsConsentKey, value);
    AnalyticsService.enabled = value;
    // The Dart flag only covers the [_log] events; this stops the legacy
    // methods and Firebase's automatic events too.
    await AnalyticsService.setAnalyticsCollectionEnabled(value);
  }
}

final analyticsConsentProvider =
    NotifierProvider<AnalyticsConsent, bool>(AnalyticsConsent.new);
