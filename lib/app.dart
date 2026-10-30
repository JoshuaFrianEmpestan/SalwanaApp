import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/firebase_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/widgets/offline_banner.dart';

/// Lets the foreground-message listener show a SnackBar without needing a
/// screen-specific BuildContext.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SalwanaApp extends ConsumerStatefulWidget {
  const SalwanaApp({super.key});

  @override
  ConsumerState<SalwanaApp> createState() => _SalwanaAppState();
}

class _SalwanaAppState extends ConsumerState<SalwanaApp> {
  String? _registeredForUid;

  @override
  void initState() {
    super.initState();
    // Foreground push (§12) — background/terminated delivery is handled by
    // the platform (web service worker / OS) once a real Firebase project
    // is configured; this only covers the app-open case, which the OS
    // never surfaces on its own.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      final text = [notification.title, notification.body].where((s) => s != null && s.isNotEmpty).join(': ');
      if (text.isEmpty) return;
      scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.listen(appUserProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null && user.isActive && _registeredForUid != user.id) {
        _registeredForUid = user.id;
        ref.read(pushNotificationServiceProvider).registerForUser(user.id);
      } else if (user == null) {
        _registeredForUid = null;
      }
    });

    return MaterialApp.router(
      title: 'Salwana',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      builder: (context, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
