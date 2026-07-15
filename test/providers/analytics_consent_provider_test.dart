import 'package:flowgroove/providers/analytics_consent_provider.dart';
import 'package:flowgroove/services/analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('analyticsConsentProvider', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(() => AnalyticsService.enabled = true);
    });

    test('defaults to true (on) before the async load resolves', () {
      expect(container.read(analyticsConsentProvider), isTrue);
    });

    test('loads a previously-persisted false value and applies it', () async {
      SharedPreferences.setMockInitialValues({
        'app.analytics_consent': false,
      });
      container = ProviderContainer();
      addTearDown(container.dispose);

      // Construct the notifier (defaults to true synchronously)...
      expect(container.read(analyticsConsentProvider), isTrue);
      // ...then the async load reconciles with the stored value.
      await Future<void>.delayed(Duration.zero);
      expect(container.read(analyticsConsentProvider), isFalse);
      expect(AnalyticsService.enabled, isFalse);
    });

    test('toggle flips state, persists it, and updates AnalyticsService.enabled', () async {
      // Let the initial load settle first.
      await Future<void>.delayed(Duration.zero);
      expect(container.read(analyticsConsentProvider), isTrue);

      await container.read(analyticsConsentProvider.notifier).toggle();

      expect(container.read(analyticsConsentProvider), isFalse);
      expect(AnalyticsService.enabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app.analytics_consent'), isFalse);
    });

    test('persists across a fresh container (new app session)', () async {
      await Future<void>.delayed(Duration.zero);
      await container.read(analyticsConsentProvider.notifier).toggle();
      expect(container.read(analyticsConsentProvider), isFalse);

      final freshContainer = ProviderContainer();
      addTearDown(freshContainer.dispose);
      // Defaults to true synchronously, then reconciles from storage.
      expect(freshContainer.read(analyticsConsentProvider), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(freshContainer.read(analyticsConsentProvider), isFalse);
    });
  });
}
