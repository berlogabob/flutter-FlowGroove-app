/// Integration Test Helpers
///
/// Comprehensive helpers for integration testing user flows,
/// navigation, and state management.
///
/// Usage:
/// ```dart
/// import 'package:flutter_test/flutter_test.dart';
/// import '../helpers/integration_test_helpers.dart';
///
/// void main() {
///   testIntegration('complete flow', () async {
///     final tester = IntegrationTester();
///     await tester.signIn();
///     await tester.navigateToBands();
///     await tester.createBand('Test Band');
///   });
/// }
/// ```

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'mocks.mocks.dart';
import 'test_helpers.dart';

/// Test data factory for creating mock entities
class TestDataFactory {
  static String generateEmail([int? seed]) {
    final id = seed ?? DateTime.now().millisecondsSinceEpoch;
    return 'test$userId$id@example.com';
  }

  static String generateBandName([int? seed]) {
    final id = seed ?? DateTime.now().millisecondsSinceEpoch;
    return 'Test Band $id';
  }

  static String generateSongTitle([int? seed]) {
    final id = seed ?? DateTime.now().millisecondsSinceEpoch;
    return 'Test Song $id';
  }

  static String generateSetlistName([int? seed]) {
    final id = seed ?? DateTime.now().millisecondsSinceEpoch;
    return 'Test Setlist $id';
  }

  static String get userId => 'test-user-${DateTime.now().millisecondsSinceEpoch}';
  static String get bandId => 'band-${DateTime.now().millisecondsSinceEpoch}';
  static String get songId => 'song-${DateTime.now().millisecondsSinceEpoch}';
  static String get setlistId => 'setlist-${DateTime.now().millisecondsSinceEpoch}';
}

/// Integration test fixture for authentication flows
class AuthIntegrationFixture {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockUserCredential mockCredential;

  void setUp() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockCredential = MockUserCredential();

    // Setup default mock behaviors
    when(mockCredential.user).thenReturn(mockUser);
    when(mockUser.uid).thenReturn(TestDataFactory.userId);
    when(mockUser.email).thenReturn(TestDataFactory.generateEmail());
    when(mockUser.displayName).thenReturn('Test User');
    when(mockUser.isAnonymous).thenReturn(false);
    when(mockUser.emailVerified).thenReturn(false);
    when(mockUser.photoURL).thenReturn(null);
  }

  void setupSuccessfulSignUp() {
    when(
      mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ),
    ).thenAnswer((_) async => mockCredential);

    when(mockUser.sendEmailVerification()).thenAnswer((_) async => {});
  }

  void setupSuccessfulSignIn() {
    when(
      mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ),
    ).thenAnswer((_) async => mockCredential);
  }

  void setupSuccessfulSignOut() {
    when(mockAuth.signOut()).thenAnswer((_) async => {});
  }

  void setupPasswordReset() {
    when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
        .thenAnswer((_) async => {});
  }

  void setupAuthStateChanges() {
    when(mockAuth.authStateChanges())
        .thenAnswer((_) => Stream<User?>.value(mockUser));
  }

  void setupFailedSignUp(String errorCode, String message) {
    when(
      mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ),
    ).thenThrow(
      FirebaseAuthException(code: errorCode, message: message),
    );
  }

  void setupFailedSignIn(String errorCode, String message) {
    when(
      mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ),
    ).thenThrow(
      FirebaseAuthException(code: errorCode, message: message),
    );
  }
}

/// Integration test fixture for Firestore operations
/// Note: For complex Firestore mocking, use direct mocks in test files
/// Type issues with Firestore mocks require workarounds - use direct mocking instead
class FirestoreIntegrationFixture {
  late MockFirebaseFirestore mockFirestore;
  // late MockCollectionReference mockCollection;
  // late MockDocumentReference mockDocument;
  // late MockQuerySnapshot mockQuerySnapshot;
  // late MockDocumentSnapshot mockDocumentSnapshot;

  void setUp() {
    mockFirestore = MockFirebaseFirestore();
    // Type issues with Firestore mocks - use direct mocking in tests
    // mockCollection = MockCollectionReference();
    // mockDocument = MockDocumentReference();
    // mockQuerySnapshot = MockQuerySnapshot();
    // mockDocumentSnapshot = MockDocumentSnapshot();
  }

  // Methods commented out due to Firestore mock type incompatibilities
  // Use direct mocking in test files instead
  // void setupCollection(String collectionPath) {
  //   when(mockFirestore.collection(collectionPath))
  //       .thenAnswer((_) => mockCollection);
  // }

  // void setupDocument(String docId) {
  //   when(mockCollection.doc(docId))
  //       .thenAnswer((_) => mockDocument);
  // }

  // void setupSuccessfulCreate() {
  //   when(mockDocument.set(any, any)).thenAnswer((_) async => {});
  // }

  // void setupSuccessfulRead(Map<String, dynamic> data) {
  //   when(mockDocumentSnapshot.exists).thenReturn(true);
  //   when(mockDocumentSnapshot.data()).thenReturn(data);
  //   when(mockDocument.get(any)).thenAnswer((_) async => mockDocumentSnapshot);
  // }

  // void setupSuccessfulUpdate() {
  //   when(mockDocument.update(any)).thenAnswer((_) async => {});
  // }

  // void setupSuccessfulDelete() {
  //   when(mockDocument.delete()).thenAnswer((_) async => {});
  // }

  // void setupQueryResults(List<Map<String, dynamic>> documents) {
  //   final mockDocs = documents.map((data) {
  //     final doc = MockDocumentSnapshot();
  //     when(doc.exists).thenReturn(true);
  //     when(doc.data()).thenReturn(data);
  //     when(doc.id).thenReturn('doc-${DateTime.now().millisecondsSinceEpoch}');
  //     return doc;
  //   }).toList();

  //   when(mockQuerySnapshot.docs).thenAnswer((_) => mockDocs);
  //   when(mockQuerySnapshot.size).thenReturn(documents.length);
  //   when(mockCollection.get(any)).thenAnswer((_) async => mockQuerySnapshot);
  // }

  // void setupEmptyQuery() {
  //   when(mockQuerySnapshot.docs).thenReturn([]);
  //   when(mockQuerySnapshot.size).thenReturn(0);
  //   when(mockCollection.get(any)).thenAnswer((_) async => mockQuerySnapshot);
  // }

  // void setupFailedOperation(String errorCode, String message) {
  //   when(mockDocument.set(any, any)).thenThrow(
  //     FirebaseException(
  //       plugin: 'firestore',
  //       code: errorCode,
  //       message: message,
  //     ),
  //   );
  // }
}

/// Navigation tracker for testing navigation flows
class NavigationTracker extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];
  final List<Route<dynamic>> poppedRoutes = [];
  final List<Route<dynamic>> replacedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) replacedRoutes.add(newRoute);
  }

  void clear() {
    pushedRoutes.clear();
    poppedRoutes.clear();
    replacedRoutes.clear();
  }

  String? get lastPushedRouteName {
    if (pushedRoutes.isEmpty) return null;
    return pushedRoutes.last.settings.name;
  }

  bool hasPushedRoute(String routeName) {
    return pushedRoutes.any((r) => r.settings.name == routeName);
  }
}

/// Widget finder shortcuts for common UI elements
class AppFinders {
  static Finder byKeyString(String keyName) {
    return find.byKey(Key(keyName));
  }

  static Finder byIconData(IconData icon) {
    return find.byIcon(icon);
  }

  static Finder byTextContaining(String text) {
    return find.textContaining(text);
  }

  static Finder byTooltip(String tooltip) {
    return find.byTooltip(tooltip);
  }

  static Finder submitButton() {
    return find.text('Submit');
  }

  static Finder cancelButton() {
    return find.text('Cancel');
  }

  static Finder deleteButton() {
    return find.text('Delete');
  }

  static Finder confirmButton() {
    return find.text('Confirm');
  }

  static Finder emailField() {
    return find.byType(TextFormField).at(0);
  }

  static Finder passwordField() {
    return find.byType(TextFormField).at(1);
  }

  static Finder textFieldByLabel(String label) {
    return find.widgetWithText(TextFormField, label);
  }
}

/// Async utility for waiting on conditions
class AsyncWait {
  static Future<bool> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.any(finder)) return true;
    }
    return false;
  }

  static Future<bool> waitForText(
    WidgetTester tester,
    String text, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return waitFor(tester, find.text(text), timeout: timeout);
  }

  static Future<bool> waitForNotFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (!tester.any(finder)) return true;
    }
    return false;
  }
}

/// Mock annotations for generating additional mocks
@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  User,
  UserCredential,
  CollectionReference,
  DocumentReference,
  QuerySnapshot,
  DocumentSnapshot,
  WriteBatch,
  NavigationTracker,
])
void main() {}
