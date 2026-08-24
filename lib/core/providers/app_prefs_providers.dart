import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the user has already been through the onboarding intro. Seeded
/// from SharedPreferences in `main.dart` before the app starts so the
/// router's redirect logic can read it synchronously.
final onboardingSeenProvider = StateProvider<bool>((ref) => false);
