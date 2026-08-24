import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/providers/app_prefs_providers.dart';
import 'firebase_options.dart';

const _onboardSeenKey = 'salwana_onboarding_seen';

/// Run with `--dart-define=USE_FIREBASE_EMULATOR=true` to point the app at
/// the local Firebase Emulator Suite (`firebase emulators:start`) instead
/// of a real project — lets the app run fully offline against fake
/// credentials before a real Firebase project exists. Never true in a
/// release build.
const _useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useFirebaseEmulator) {
    // Use the literal IPv4 loopback address, not "localhost" — on Windows
    // "localhost" can resolve to the IPv6 loopback (::1) first, which the
    // emulators (bound to 127.0.0.1 only) never answer on. That mismatch
    // hangs the very first Auth call with no error, which looks exactly
    // like the app being stuck on the splash screen forever.
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
  }

  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen = prefs.getBool(_onboardSeenKey) ?? false;

  runApp(
    ProviderScope(
      overrides: [onboardingSeenProvider.overrideWith((ref) => onboardingSeen)],
      child: const SalwanaApp(),
    ),
  );
}
