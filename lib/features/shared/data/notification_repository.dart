import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_notification.dart';

class NotificationRepository {
  final FirebaseFirestore _db;
  NotificationRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('notifications');

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => AppNotification.fromMap(d.id, d.data())).toList());
  }

  Future<void> markRead(String id) async {
    await _col.doc(id).update({'read': true});
  }

  Future<void> markAllRead(String userId) async {
    final snap = await _col.where('userId', isEqualTo: userId).where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(firestoreProvider));
});

final myNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchNotifications(user.id);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(myNotificationsProvider).valueOrNull ?? const [];
  return notifications.where((n) => !n.read).length;
});
