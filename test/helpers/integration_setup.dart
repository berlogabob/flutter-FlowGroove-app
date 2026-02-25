/// Integration Test Helper
///
/// Centralized setup for integration tests with Firebase mocks.
/// This ensures all integration tests have consistent Firebase initialization.
///
/// Usage:
/// ```dart
/// void main() async {
///   setUpAll(() async {
///     await initializeIntegrationTests();
///   });
///   
///   testWidgets('test description', (tester) async {
///     // Your test code here
///   });
/// }
/// ```

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mocks.mocks.dart';

/// Initialize Firebase with mocks for integration tests
/// Note: Firebase is initialized with test options, actual mocking is done
/// through MockFirebaseFirestore and MockFirebaseAuth in individual tests
Future<void> initializeIntegrationTests() async {
  // Initialize Firebase with test options
  // In test environment, this uses the mock implementation
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'test-api-key',
      appId: 'test-app-id',
      messagingSenderId: 'test-sender-id',
      projectId: 'test-project',
    ),
  );
}

/// Common test utilities for integration tests
class IntegrationTestUtils {
  /// Wait for async operations to complete
  static Future<void> pumpUntilReady(WidgetTester tester, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await tester.pumpAndSettle(timeout);
  }
  
  /// Find widget by text
  static Finder byText(String text) => find.text(text);
  
  /// Find widget by key
  static Finder byKeyString(String key) => find.byKey(Key(key));
  
  /// Enter text and pump
  static Future<void> enterText(WidgetTester tester, Finder finder, String text) async {
    await tester.enterText(finder, text);
    await tester.pump();
  }
  
  /// Tap widget and pump
  static Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
  }
}
