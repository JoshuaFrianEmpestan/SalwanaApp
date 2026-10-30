import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  PaymentRepository(this._db, this._auth, this._functions);

  Future<void> pay({required String orderId, required bool simulateSuccess}) async {
    // Try the HTTP API first (works in production and local dev with the
    // Express server). Fall back to the Firebase Cloud Function when the API
    // is unreachable or the route is not deployed yet, so the flow keeps
    // working in either environment.
    bool tryFallback = false;
    String? httpError;
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
      if (resp.statusCode == 404) {
        tryFallback = true;
      } else if (resp.statusCode >= 400) {
        String msg = 'Payment could not be processed.';
        try {
          final body = jsonDecode(resp.body);
          msg = body['error'] ?? msg;
        } catch (_) {}
        // If the server says the route is missing, fall back.
        if (msg.toLowerCase().contains('cannot') || msg.toLowerCase().contains('not found')) {
          tryFallback = true;
        } else {
          throw PaymentException(msg);
        }
      }
    } catch (e) {
      if (e is PaymentException) rethrow;
      tryFallback = true;
      httpError = e.toString();
    }

    if (!tryFallback) return;

    // Fallback to Firebase Cloud Function.
    try {
      await _functions.httpsCallable('processPayment').call<Map<String, dynamic>>({
        'orderId': orderId,
        'simulateOutcome': simulateSuccess ? 'success' : 'fail',
      });
    } on FirebaseFunctionsException catch (fe) {
      throw PaymentException(fe.message ?? httpError ?? 'Payment could not be processed.');
    } catch (e) {
      throw PaymentException(httpError ?? e.toString());
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
  return PaymentRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider), ref.watch(firebaseFunctionsProvider));
});

final orderProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  return ref.watch(paymentRepositoryProvider).watchOrder(orderId);
});

final receiptProvider = StreamProvider.family<DigitalReceipt?, String>((ref, orderId) {
  return ref.watch(paymentRepositoryProvider).watchReceipt(orderId);
});
