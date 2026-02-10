// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are available only for web platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyAxQ53DQzyEkKXjo3Ry2B9pcTMvcyk4d5o",
    appId: "1:703941154390:web:43dfeaf2f6a0495e004df7",
    messagingSenderId: "703941154390",
    projectId: "repsync-app-8685c",
    authDomain: "repsync-app-8685c.firebaseapp.com",
    storageBucket: "repsync-app-8685c.firebasestorage.app",
    // measurementId: "G-DQC026CRM8" — можно оставить или убрать (не обязательно)
  );
}
