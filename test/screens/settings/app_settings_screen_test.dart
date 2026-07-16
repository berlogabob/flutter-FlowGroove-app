import 'package:flowgroove/providers/analytics_consent_provider.dart';
import 'package:flowgroove/providers/haptics_provider.dart';
import 'package:flowgroove/providers/keep_screen_on_provider.dart';
import 'package:flowgroove/providers/theme_mode_provider.dart';
import 'package:flowgroove/screens/settings/app_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('AppSettingsScreen (#129)', () {
    testWidgets('shows all v1 settings rows', (tester) async {
      await pump(tester);

      expect(find.text('Keep screen on'), findsOneWidget);
      expect(find.text('Haptics'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Quick action on song cards'), findsOneWidget);
      expect(find.text('Share usage analytics'), findsOneWidget);
      expect(find.text('AI access (MCP)'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Audio latency offset'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Audio latency offset'), findsOneWidget);
    });

    testWidgets('haptics switch flips the global provider', (tester) async {
      final container = await pump(tester);

      expect(container.read(hapticsEnabledProvider), isTrue);
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Haptics'),
      );
      await tester.pumpAndSettle();
      expect(container.read(hapticsEnabledProvider), isFalse);
    });

    testWidgets('keep-screen-on and analytics switches flip providers', (
      tester,
    ) async {
      final container = await pump(tester);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Keep screen on'));
      await tester.pumpAndSettle();
      expect(container.read(keepScreenOnProvider), isFalse);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Share usage analytics'),
      );
      await tester.pumpAndSettle();
      expect(container.read(analyticsConsentProvider), isFalse);
    });

    testWidgets('theme segmented switch sets themeModeProvider', (
      tester,
    ) async {
      final container = await pump(tester);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      await tester.tap(find.text('Light β'));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    testWidgets('back arrow is present and pops the route (web escape)', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('home-screen')),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (_, __) => const AppSettingsScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      router.pushNamed('settings');
      await tester.pumpAndSettle();

      expect(find.text('Keep screen on'), findsOneWidget);
      final back = find.byIcon(Icons.arrow_back);
      expect(back, findsOneWidget, reason: 'pushed screen must offer Back');

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('home-screen'), findsOneWidget);
    });

    testWidgets('latency stepper adjusts and clamps', (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(
        find.text('Audio latency offset'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('10 ms'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(find.text('0 ms'), findsOneWidget);
    });
  });
}
