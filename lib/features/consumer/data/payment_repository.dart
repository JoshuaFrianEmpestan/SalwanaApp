import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/digital_receipt.dart';
import '../../../models/order.dart';

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
  @override
  String toString() => message;
}

/// Client for `processPayment` plus the read-side streams the
/// payment/receipt screens need (§6, §7).
class PaymentRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;
  PaymentRepository(this._functions, this._db);

  Future<void> pay({required String orderId, required bool simulateSuccess}) async {
    try {
      await _functions.httpsCallable('processPayment').call<Map<String, dynamic>>({
        'orderId': orderId,
        'simulateOutcome': simulateSuccess ? 'success' : 'fail',
      });
    } on FirebaseFunctionsException catch (e) {
      throw PaymentException(e.message ?? 'Payment could not be processed.');
    }
  }

  Stream<Order?> watchOrder(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots().map((d) => d.exists ? Order.fromMap(d.id, d.data()!) : null);
  }

  Stream<DigitalReceipt?> watchReceipt(String orderId) {
    return _db.collection('digital_receipts').doc(orderId).snapshots().map((d) => d.exists ? DigitalReceipt.fromMap(d.id, d.data()!) : null);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(firebaseFunctionsProvider), ref.watch(firestoreProvider));
});

final orderProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  return ref.watch(paymentRepositoryProvider).watchOrder(orderId);
});

final receiptProvider = StreamProvider.family<DigitalReceipt?, String>((ref, orderId) {
  return ref.watch(paymentRepositoryProvider).watchReceipt(orderId);
});
