import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowgroove/providers/auth/auth_provider.dart';

class FirebaseEmulatorHarness {
  FirebaseEmulatorHarness._({
    required this.app,
    required this.auth,
    required this.firestore,
    required this.namespace,
  });

  static bool _configured = false;
  static int _counter = 0;

  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final String namespace;

  static Future<FirebaseEmulatorHarness> bootstrap() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'demo-api-key',
          appId: '1:703941154390:ios:test-harness',
          messagingSenderId: '703941154390',
          projectId: 'repsync-app-8685c',
        ),
      );
    }

    final app = Firebase.app();
    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);

    if (!_configured) {
      await auth.useAuthEmulator('127.0.0.1', 9099);
      firestore.useFirestoreEmulator(
        '127.0.0.1',
        8080,
        sslEnabled: false,
        automaticHostMapping: false,
      );
      firestore.settings = const Settings(persistenceEnabled: false);
      _configured = true;
    }

    return FirebaseEmulatorHarness._(
      app: app,
      auth: auth,
      firestore: firestore,
      namespace: 'it_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  List<dynamic> providerOverrides() {
    return [
      firebaseAuthProvider.overrideWithValue(auth),
      firebaseFirestoreProvider.overrideWithValue(firestore),
    ];
  }

  String uniqueId(String prefix) {
    _counter += 1;
    return '${namespace}_${prefix}_$_counter';
  }

  String uniqueEmail({String prefix = 'user'}) {
    return '${uniqueId(prefix)}@example.com';
  }

  Future<UserCredential> createAndSeedUser({
    String? email,
    String password = 'Password123!',
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email ?? uniqueEmail(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      await seedUserDoc(user.uid, email: user.email);
    }
    return credential;
  }

  Future<void> seedUserDoc(String uid, {String? email}) async {
    final now = Timestamp.fromDate(DateTime.now());
    await firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': email?.split('@').first ?? uid,
      'accessRole': 'member',
      'bandIds': <String>[],
      'musicRoles': <String>[],
      'systemTags': <String>[],
      'telegramConsent': false,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> clearUserData(String uid) async {
    await _deleteSubcollection('users/$uid/setlists');
    await _deleteSubcollection('users/$uid/songs');
    await _deleteSubcollection('users/$uid/bands');
    await firestore.collection('users').doc(uid).delete().catchError((_) {});
  }

  Future<void> deleteCurrentUser() async {
    final user = auth.currentUser;
    if (user == null) return;
    await clearUserData(user.uid);
    await user.delete().catchError((_) {});
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<void> _deleteSubcollection(String path) async {
    final snapshot = await firestore.collection(path).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
