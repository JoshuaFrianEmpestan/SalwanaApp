import 'dart:async';
import 'package:flutter/foundation.dart';

/// Bridges any [Stream] to a [Listenable] so GoRouter can re-evaluate its
/// `redirect` callback whenever auth/profile state changes, without
/// recreating the whole router (which would blow away navigation state).
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
