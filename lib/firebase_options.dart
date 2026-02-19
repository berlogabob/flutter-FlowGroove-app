// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    } else if (Platform.isAndroid) {
      return android;
    } else if (Platform.isIOS) {
      return ios;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAxQ53DQzyEkKXjo3Ry2B9pcTMvcyk4d5o',
    appId: '1:703941154390:web:43dfeaf2f6a0495e004df7',
    messagingSenderId: '703941154390',
    projectId: 'repsync-app-8685c',
    authDomain: 'repsync-app-8685c.firebaseapp.com',
    storageBucket: 'repsync-app-8685c.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAxQ53DQzyEkKXjo3Ry2B9pcTMvcyk4d5o',
    appId: '1:703941154390:android:43dfeaf2f6a0495e004df7',
    messagingSenderId: '703941154390',
    projectId: 'repsync-app-8685c',
    authDomain: 'repsync-app-8685c.firebaseapp.com',
    storageBucket: 'repsync-app-8685c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAxQ53DQzyEkKXjo3Ry2B9pcTMvcyk4d5o',
    appId: '1:703941154390:ios:43dfeaf2f6a0495e004df7',
    messagingSenderId: '703941154390',
    projectId: 'repsync-app-8685c',
    authDomain: 'repsync-app-8685c.firebaseapp.com',
    storageBucket: 'repsync-app-8685c.firebasestorage.app',
    iosBundleId: 'com.example.flutterRepsyncApp',
  );
}
