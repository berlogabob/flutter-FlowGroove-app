import 'dart:async';
import 'dart:io' show HttpClient, HttpClientRequest;

import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../design_render/fixtures.dart';
import '../helpers/routed_test_harness.dart';

class _HangingHttpClient extends Fake implements HttpClient {
  @override
  set autoUncompress(bool value) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Completer<HttpClientRequest>().future;
}

Future<void> _openSheet(
  WidgetTester tester, {
  Map<String, dynamic>? userDoc,
}) async {
  // The upload's photo URL never answers: no image error, a plain avatar.
  debugNetworkImageHttpClientProvider = _HangingHttpClient.new;
  addTearDown(() => debugNetworkImageHttpClientProvider = null);
  await pumpRoutedTestApp(
    tester,
    initialLocation: '/main/profile',
    overrides: [
      ...renderOverrides(
        key: userDoc == null ? 'profile_currently_using' : 'profile',
      ),
      if (userDoc != null)
        userDocProvider.overrideWith((ref) => Stream.value(userDoc)),
    ],
    productionRoutes: true,
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .ancestor(
          of: find.byType(CircleAvatar).first,
          matching: find.byType(GestureDetector),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Widget? _trailing(WidgetTester tester, String title) =>
    tester.widget<ListTile>(find.widgetWithText(ListTile, title)).trailing;

void main() {
  testWidgets('photo sheet: in-use mark is trailing green text', (
    tester,
  ) async {
    await _openSheet(tester);

    for (final t in [
      'Use Telegram Photo',
      'Import photo from Telegram',
      'Use Google Photo',
      'Take Photo',
      'Choose from Gallery',
      'Remove Photo',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // Uploaded photo: both upload tiles carry the mark, others do not.
    for (final t in ['Take Photo', 'Choose from Gallery']) {
      final mark = _trailing(tester, t)! as Text;
      expect(mark.data, '✓ Currently using');
      expect(mark.style!.color, MonoPulseColors.successGreen);
    }
    expect(_trailing(tester, 'Use Telegram Photo'), isNull);
    expect(_trailing(tester, 'Use Google Photo'), isNull);
    expect(_trailing(tester, 'Remove Photo'), isNull);
    // Neutral icons: no blue Telegram, no red Remove.
    for (final tile in tester.widgetList<ListTile>(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListTile),
      ),
    )) {
      expect((tile.leading! as Icon).color, isNull);
    }
  });

  testWidgets('photo sheet: unlinked Telegram offers linking', (tester) async {
    await _openSheet(tester, userDoc: {'photoSource': 'upload'});

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Link Telegram'),
      ),
      findsOneWidget,
    );
    expect(find.text('Import photo from Telegram'), findsOneWidget);
    expect(find.text('Remove Photo'), findsNothing);
    expect(find.text('✓ Currently using'), findsNothing);
  });

  testWidgets('photo sheet: a tile closes the sheet', (tester) async {
    await _openSheet(tester);

    await tester.tap(find.text('Remove Photo'));
    await tester.pumpAndSettle();

    expect(find.text('Choose from Gallery'), findsNothing);
  });
}
