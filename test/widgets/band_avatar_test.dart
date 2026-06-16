import 'package:flowgroove/widgets/band_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows band initial when no photoURL', (tester) async {
    await tester.pumpWidget(host(
      const BandAvatar(photoURL: null, bandName: 'Nightcrawlers'),
    ));
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('uses NetworkImage when photoURL is set', (tester) async {
    // Suppress the expected network-load failure from the test HTTP client.
    final List<dynamic> imageErrors = [];
    final savedHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('NetworkImageLoadException') ||
          details.exception.toString().contains('HTTP request failed')) {
        imageErrors.add(details.exception);
        return;
      }
      savedHandler?.call(details);
    };

    await tester.pumpWidget(host(
      const BandAvatar(
        photoURL: 'https://example.com/b1.jpg',
        bandName: 'Nightcrawlers',
      ),
    ));
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<NetworkImage>());

    FlutterError.onError = savedHandler;
  });
}
