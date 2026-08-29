import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/firebase_providers.dart';

/// Push notification registration (§12 "use push notifications where
/// supported, but retain an in-app notification center as the primary
/// record"). Every step here is best-effort and wrapped so a failure —
/// e.g. no real Firebase project/VAPID key configured yet, or the user
/// declining the permission prompt — never breaks the app. The in-app
/// center (notifications collection) is authoritative regardless.
class PushNotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  PushNotificationService(this._messaging, this._db);

  Future<void> registerForUser(String uid) async {
    try {
      final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);

      _messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));
    } catch (e) {
      // Expected in the local emulator (no real project/VAPID key) and on
      // platforms without messaging support — nothing to do here.
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).update({'fcmToken': token});
    } catch (_) {}
  }

  Future<void> clearTokenOnLogout(String uid) async {
    try {
      await _messaging.deleteToken();
      await _db.collection('users').doc(uid).update({'fcmToken': null});
    } catch (_) {}
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(FirebaseMessaging.instance, ref.watch(firestoreProvider));
});
