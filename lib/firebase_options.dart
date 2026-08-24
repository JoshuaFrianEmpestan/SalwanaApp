// GENERATED PLACEHOLDER — replace this entire file by running:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// from the project root, after creating a Firebase project at
// https://console.firebase.google.com and enabling: Authentication
// (Email/Password), Firestore, Storage, Cloud Functions, and Cloud
// Messaging. The CLI overwrites this file with your real project's keys —
// do not commit real secrets here if this repo is ever made public; keep
// this file out of version control for production apps and inject config
// via CI secrets instead where possible.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run `flutterfire configure` to generate real options.',
        );
    }
  }

  // These are well-formed but fake ("demo-" project) values — they satisfy
  // the SDK's local format validation and work fine against the Firebase
  // Local Emulator Suite (see USE_FIREBASE_EMULATOR in main.dart), but they
  // are NOT a real project and will not work against production Firebase.
  // `flutterfire configure` replaces every value below with your real ones.
  static const web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:1234567890:web:abcdef1234567890abcdef',
    messagingSenderId: '1234567890',
    projectId: 'demo-salwana',
    authDomain: 'demo-salwana.firebaseapp.com',
    storageBucket: 'demo-salwana.appspot.com',
  );

  static const android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:1234567890:android:abcdef1234567890abcdef',
    messagingSenderId: '1234567890',
    projectId: 'demo-salwana',
    storageBucket: 'demo-salwana.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:1234567890:ios:abcdef1234567890abcdef',
    messagingSenderId: '1234567890',
    projectId: 'demo-salwana',
    storageBucket: 'demo-salwana.appspot.com',
    iosBundleId: 'com.example.salwanaapp',
  );
}
