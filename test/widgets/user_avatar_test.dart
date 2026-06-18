import 'package:cached_network_image/cached_network_image.dart';
import 'package:flowgroove/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows initials when no photoURL', (tester) async {
    await tester.pumpWidget(host(
      const UserAvatar(photoURL: null, displayName: 'Andre Berloga'),
    ));
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('uses a cached network image when photoURL is an http url', (
    tester,
  ) async {
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
      const UserAvatar(
        photoURL: 'https://example.com/u1.jpg',
        displayName: 'Andre',
      ),
    ));
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<CachedNetworkImageProvider>());

    FlutterError.onError = savedHandler;
  });

  testWidgets('falls back to ? when name is empty', (tester) async {
    await tester.pumpWidget(host(
      const UserAvatar(photoURL: null, displayName: ''),
    ));
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('applies backgroundColor when provided', (tester) async {
    await tester.pumpWidget(host(
      const UserAvatar(
        photoURL: null,
        displayName: 'Andre',
        backgroundColor: Colors.orange,
      ),
    ));
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, Colors.orange);
  });
}
