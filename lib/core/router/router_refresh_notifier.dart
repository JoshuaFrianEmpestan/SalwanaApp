import 'package:flutter/foundation.dart';

/// [Listenable] that GoRouter calls `redirect` on whenever it fires. Fed by
/// `ref.listen` on the auth/profile providers (see app_router.dart) rather
/// than the deprecated `.stream` provider modifier.
class RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
