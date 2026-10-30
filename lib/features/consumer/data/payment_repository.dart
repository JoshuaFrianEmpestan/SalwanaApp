import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  PaymentRepository(this._db, this._auth);

  Future<void> pay({required String orderId, required bool simulateSuccess}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw PaymentException('Not signed in.');
      final token = await user.getIdToken();
      final resp = await http.post(
        Uri.parse('https://salwanaapp.onrender.com/processPayment'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'orderId': orderId,
          'simulateOutcome': simulateSuccess ? 'success' : 'fail',
        }),
      );
      if (resp.statusCode >= 400) {
        String msg = 'Payment could not be processed.';
        try {
          final body = jsonDecode(resp.body);
          msg = body['error'] ?? msg;
        } catch (_) {}
        throw PaymentException(msg);
      }
    } catch (e) {
      if (e is PaymentException) rethrow;
      throw PaymentException(e.toString());
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
  return PaymentRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider));
});

final orderProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  return ref.watch(paymentRepositoryProvider).watchOrder(orderId);
});

final receiptProvider = StreamProvider.family<DigitalReceipt?, String>((ref, orderId) {
  return ref.watch(paymentRepositoryProvider).watchReceipt(orderId);
});
