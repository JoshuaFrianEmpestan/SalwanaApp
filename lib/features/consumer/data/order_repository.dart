import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/order.dart';

class OrderActionException implements Exception {
  final String message;
  OrderActionException(this.message);
  @override
  String toString() => message;
}

/// Order list streams plus the `updateOrderStatus` Cloud Function client
/// (§8) — every fulfillment/cancel/refund action is server-validated the
/// same way reservation actions are (module 6).
class OrderRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  OrderRepository(this._db, this._functions);

  Stream<List<Order>> watchConsumerOrders(String consumerId) {
    return _db
        .collection('orders')
        .where('consumerId', isEqualTo: consumerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Order.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Order>> watchMerchantOrders(String merchantId) {
    return _db
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Order.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> _act(String orderId, String action, {String? reason}) async {
    try {
      await _functions.httpsCallable('updateOrderStatus').call<Map<String, dynamic>>({
        'orderId': orderId,
        'action': action,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw OrderActionException(e.message ?? 'Could not update this order.');
    }
  }

  Future<void> markPreparing(String orderId) => _act(orderId, 'preparing');
  Future<void> markReadyForPickup(String orderId) => _act(orderId, 'readyForPickup');
  Future<void> markOutForDelivery(String orderId) => _act(orderId, 'outForDelivery');
  Future<void> markCompleted(String orderId) => _act(orderId, 'completed');
  Future<void> cancel(String orderId, String? reason) => _act(orderId, 'cancel', reason: reason);
  Future<void> refund(String orderId) => _act(orderId, 'refund');
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});

final consumerOrdersProvider = StreamProvider<List<Order>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchConsumerOrders(user.id);
});

final merchantOrdersProvider = StreamProvider<List<Order>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchMerchantOrders(user.id).handleError((e, st) {
    // ignore: avoid_print
    print('merchantOrdersProvider error: $e');
  });
});
