import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'mocks.dart';

// ProviderOverride for testing
typedef ProviderOverride = Override;

/// Creates a [ProviderContainer] for testing
ProviderContainer createProviderContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// Helper function to pump and settle the UI
Future<void> pumpAndSettleUntil(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Creates a mock stream that emits values sequentially
Stream<T> createMockStream<T>(List<T> values, {Duration? delay}) async* {
  for (final value in values) {
    if (delay != null) {
      await Future.delayed(delay);
    }
    yield value;
  }
}

/// Creates an empty stream for testing
Stream<T> createEmptyStream<T>() async* {
  // Empty stream
}

/// Creates a stream that throws an error
Stream<T> createErrorStream<T>(Object error) async* {
  throw error;
}

/// Pump widget with ProviderScope for Riverpod testing
Future<void> pumpWidgetWithProvider(
  WidgetTester tester,
  Widget widget, {
  ProviderContainer? container,
}) async {
  final providerContainer = container ?? ProviderContainer();
  addTearDown(providerContainer.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: providerContainer,
      child: MaterialApp(
        home: Scaffold(body: widget),
      ),
    ),
  );

  await tester.pump();
}

/// Pump widget with ProviderScope and custom providers
Future<void> pumpWidgetWithProviders(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
}) async {
  final providerContainer = ProviderContainer(overrides: overrides);
  addTearDown(providerContainer.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: providerContainer,
      child: MaterialApp(
        home: Scaffold(body: widget),
      ),
    ),
  );

  await tester.pump();
}

/// Pump widget with full app setup including navigation
Future<void> pumpAppWidget(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
  List<NavigatorObserver>? navigatorObservers,
}) async {
  final providerContainer = ProviderContainer(overrides: overrides);
  addTearDown(providerContainer.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: providerContainer,
      child: MaterialApp(
        home: widget,
        navigatorObservers: navigatorObservers ?? [],
      ),
    ),
  );

  await tester.pump();
}

/// Find widget by text content
Finder findText(String text) {
  return find.text(text);
}

/// Find widget by key
Finder findKey(Key key) {
  return find.byKey(key);
}

/// Find widget by type
Finder findType(Type type) {
  return find.byType(type);
}

/// Find icon by icon data
Finder findIcon(IconData icon) {
  return find.byIcon(icon);
}

/// Enter text into a text field
Future<void> enterText(WidgetTester tester, Finder finder, String text) async {
  await tester.enterText(finder, text);
  await tester.pump();
}

/// Tap on a widget
Future<void> tapWidget(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
}

/// Wait for a widget to appear
Future<void> waitForWidget(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  expect(finder, findsOneWidget);
}

/// Verify widget is not found
void verifyNotFound(Finder finder) {
  expect(finder, findsNothing);
}

/// Verify widget is found exactly once
void verifyFoundOnce(Finder finder) {
  expect(finder, findsOneWidget);
}

/// Verify widget is found multiple times
void verifyFoundN(Finder finder, int count) {
  expect(finder, findsNWidgets(count));
}

/// Create mock user credential
UserCredential createMockUserCredential({
  String uid = 'test-user-id',
  String? email = 'test@example.com',
  String? displayName,
}) {
  final mockCredential = MockCredential();
  final mockUser = MockUser();

  when(mockCredential.user).thenReturn(mockUser);
  when(mockUser.uid).thenReturn(uid);
  when(mockUser.email).thenReturn(email);
  when(mockUser.displayName).thenReturn(displayName);
  when(mockUser.isAnonymous).thenReturn(false);

  return mockCredential;
}
