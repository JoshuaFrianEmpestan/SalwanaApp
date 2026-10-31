import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/providers/app_prefs_providers.dart';
import 'core/providers/theme_provider.dart';
import 'firebase_options.dart';

const _onboardSeenKey = 'salwana_onboarding_seen';
const _themeModeKey = 'theme_mode';

/// Run with `--dart-define=USE_FIREBASE_EMULATOR=true` to point the app at
/// the local Firebase Emulator Suite (`firebase emulators:start`) instead
/// of a real project — lets the app run fully offline against fake
/// credentials before a real Firebase project exists. Never true in a
/// release build.
const _useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline support (§7): cache reads/writes locally so the app stays
  // usable (and queues writes) when connectivity drops. On web this is
  // IndexedDB-backed and only reliable in a single tab; best-effort since
  // some browsers/private-mode sessions block IndexedDB entirely.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } catch (_) {
    // Persistence unavailable (e.g. multiple open tabs on web) — the app
    // still works, just without an offline cache.
  }

  if (_useFirebaseEmulator) {
    // Use the literal IPv4 loopback address, not "localhost" — on Windows
    // "localhost" can resolve to the IPv6 loopback (::1) first, which the
    // emulators (bound to 127.0.0.1 only) never answer on. That mismatch
    // hangs the very first Auth call with no error, which looks exactly
    // like the app being stuck on the splash screen forever.
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
    FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
  }

  // Enlarge the in-memory image cache so images aren't evicted (and rendered
  // black) when switching tabs on web.
  PaintingBinding.instance.imageCache.maximumSize = 10000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 * 1024 * 1024;

  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen = prefs.getBool(_onboardSeenKey) ?? false;
  final savedThemeMode = themeModeFromName(prefs.getString(_themeModeKey));

  runApp(
    ProviderScope(
      overrides: [
        onboardingSeenProvider.overrideWith((ref) => onboardingSeen),
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier(prefs, savedThemeMode)),
      ],
      child: const SalwanaApp(),
    ),
  );
}
