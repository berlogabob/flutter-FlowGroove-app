import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/screens/bands/create_band_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/error_banner.dart';
import 'package:flowgroove/widgets/primary_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final isDemo in [true, false]) {
    testWidgets('create band shows ${isDemo ? 'demo lock panel' : 'form'}', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isDemoUserProvider.overrideWithValue(isDemo),
            canEditProvider.overrideWithValue(!isDemo),
          ],
          child: const MaterialApp(home: CreateBandScreen()),
        ),
      );

      if (isDemo) {
        expect(find.text('Demo accounts are read-only'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.byType(Form), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(PrimaryActionBar), findsNothing);
        expect(find.byType(ErrorBanner), findsNothing);
        expect(
          tester.widget<Card>(find.byType(Card)).color,
          MonoPulsePalette.dark.surfaceRaised,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Sign Up'),
              )
              .onPressed,
          isNotNull,
        );
      } else {
        expect(find.text('Demo accounts are read-only'), findsNothing);
        expect(find.text('Sign Up'), findsNothing);
        expect(find.byType(Form), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('Band Name *'), findsOneWidget);
        expect(find.text('Description'), findsOneWidget);
        expect(
          tester
              .widget<PrimaryActionBar>(find.byType(PrimaryActionBar))
              .onPressed,
          isNotNull,
        );
        await tester.enterText(find.byType(TextFormField).first, 'My band');
        expect(find.text('My band'), findsOneWidget);
      }
    });
  }
}
