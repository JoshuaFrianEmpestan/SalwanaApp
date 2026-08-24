import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/providers/app_prefs_providers.dart';
import 'firebase_options.dart';

const _onboardSeenKey = 'salwana_onboarding_seen';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen = prefs.getBool(_onboardSeenKey) ?? false;

  runApp(
    ProviderScope(
      overrides: [onboardingSeenProvider.overrideWith((ref) => onboardingSeen)],
      child: const SalwanaApp(),
    ),
  );
}
