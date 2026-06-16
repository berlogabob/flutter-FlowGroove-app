// ignore_for_file: directives_ordering

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/connectivity_service.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/offline_indicator.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('OfflineIndicator', () {
    final offlineOverrides = [offlineProvider.overrideWithValue(true)];

    testWidgets('renders banner variant', (tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator.banner(),
        overrides: offlineOverrides,
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(
        find.text('Offline - Some features may be limited'),
        findsOneWidget,
      );
    });

    testWidgets('renders chip variant', (tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator.chip(),
        overrides: offlineOverrides,
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('renders minimal variant', (tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator.minimal(),
        overrides: offlineOverrides,
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('uses theme colors', (tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator.banner(),
        overrides: offlineOverrides,
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
      expect(icon.color, MonoPulseColors.accentOrange);
    });

    testWidgets('banner is full width', (tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator.banner(),
        overrides: offlineOverrides,
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints, isNotNull);
      expect(container.constraints!.maxWidth, double.infinity);
    });

    testWidgets('renders nothing when online', (tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator.banner(),
        overrides: [offlineProvider.overrideWithValue(false)],
      );

      expect(find.byIcon(Icons.wifi_off), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
