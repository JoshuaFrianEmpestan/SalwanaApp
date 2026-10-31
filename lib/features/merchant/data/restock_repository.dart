import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/restock_request.dart';
import '../../../models/supplier.dart';

class RestockException implements Exception {
  final String message;
  RestockException(this.message);
  @override
  String toString() => message;
}

/// Restocking workflow (§9) shared by both the merchant (create/confirm)
/// and supplier (respond/dispatch) sides — same cross-role pattern as
/// reservations and orders.
class RestockRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  RestockRepository(this._db, this._auth, this._functions);

  Stream<List<SupplierProfile>> watchActiveSuppliers() {
    return _db
        .collection('suppliers')
        .where('verificationStatus', isEqualTo: 'active')
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => SupplierProfile.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => a.companyName.compareTo(b.companyName));
          return list;
        });
  }

  Stream<SupplierProfile?> watchSupplier(String supplierId) {
    return _db.collection('suppliers').doc(supplierId).snapshots().map((d) => d.exists ? SupplierProfile.fromMap(d.id, d.data()!) : null);
  }

  Future<String> createRequest({
    required String supplierId,
    required List<RestockRequestItem> items,
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw RestockException('Not signed in.');
      final token = await user.getIdToken();
      final resp = await http.post(
        Uri.parse('https://salwanaapp.onrender.com/createRestockRequest'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'supplierId': supplierId,
          'items': items
              .map((i) => {
                    'productId': i.productId,
                    'requestedQuantity': i.requestedQuantity,
                    'estimatedUnitCost': i.estimatedUnitCost,
                  })
              .toList(),
          'notes': notes,
        }),
      );
      if (resp.statusCode >= 400) {
        String msg = 'Could not create restocking request.';
        try {
          final body = jsonDecode(resp.body);
          msg = body['error'] ?? msg;
        } catch (_) {}
        throw RestockException(msg);
      }
      final data = jsonDecode(resp.body);
      return (data['restockRequestId'] as String?) ?? '';
    } catch (e) {
      if (e is RestockException) rethrow;
      throw RestockException(e.toString());
    }
  }

  Future<void> _respond(String requestId, String action, {String? reason, DateTime? estimatedDelivery}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw RestockException('Not signed in.');
      final token = await user.getIdToken();
      final resp = await http.post(
        Uri.parse('https://salwanaapp.onrender.com/respondToRestockRequest'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'restockRequestId': requestId,
          'action': action,
          'reason': reason,
          'estimatedDeliveryIso': estimatedDelivery?.toIso8601String(),
        }),
      );
      if (resp.statusCode >= 400) {
        String msg = 'Could not update this request.';
        try {
          final body = jsonDecode(resp.body);
          msg = body['error'] ?? msg;
        } catch (_) {}
        throw RestockException(msg);
      }
    } catch (e) {
      if (e is RestockException) rethrow;
      throw RestockException(e.toString());
    }
  }

  Future<void> accept(String requestId, {DateTime? estimatedDelivery}) => _respond(requestId, 'accept', estimatedDelivery: estimatedDelivery);
  Future<void> reject(String requestId, String reason) => _respond(requestId, 'reject', reason: reason);
  Future<void> markProcessing(String requestId) => _respond(requestId, 'processing');
  Future<void> dispatch(String requestId) => _respond(requestId, 'dispatch');
  Future<void> cancel(String requestId) => _respond(requestId, 'cancel');

  Future<void> confirmDelivery(String requestId, List<RestockRequestItem> receivedItems) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw RestockException('Not signed in.');
      final token = await user.getIdToken();
      final resp = await http.post(
        Uri.parse('https://salwanaapp.onrender.com/confirmRestockDelivery'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'restockRequestId': requestId,
          'receivedItems': receivedItems
              .map((i) => {'productId': i.productId, 'receivedQuantity': i.receivedQuantity ?? 0})
              .toList(),
        }),
      );
      if (resp.statusCode >= 400) {
        String msg = 'Could not confirm delivery.';
        try {
          final body = jsonDecode(resp.body);
          msg = body['error'] ?? msg;
        } catch (_) {}
        throw RestockException(msg);
      }
    } catch (e) {
      if (e is RestockException) rethrow;
      throw RestockException(e.toString());
    }
  }

  Stream<List<RestockRequest>> watchMerchantRequests(String merchantId) {
    return _db
        .collection('restock_requests')
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => RestockRequest.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<RestockRequest>> watchSupplierRequests(String supplierId) {
    return _db
        .collection('restock_requests')
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => RestockRequest.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<RestockRequest?> watchRequest(String id) {
    return _db.collection('restock_requests').doc(id).snapshots().map((d) => d.exists ? RestockRequest.fromMap(d.id, d.data()!) : null);
  }
}

final restockRepositoryProvider = Provider<RestockRepository>((ref) {
  return RestockRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider), ref.watch(firebaseFunctionsProvider));
});

final activeSuppliersProvider = StreamProvider<List<SupplierProfile>>((ref) {
  return ref.watch(restockRepositoryProvider).watchActiveSuppliers();
});

final supplierProfileByIdProvider = StreamProvider.family<SupplierProfile?, String>((ref, id) {
  return ref.watch(restockRepositoryProvider).watchSupplier(id);
});

final merchantRestockRequestsProvider = StreamProvider<List<RestockRequest>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(restockRepositoryProvider).watchMerchantRequests(user.id);
});

final supplierRestockRequestsProvider = StreamProvider<List<RestockRequest>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(restockRepositoryProvider).watchSupplierRequests(user.id);
});

final restockRequestDetailProvider = StreamProvider.family<RestockRequest?, String>((ref, id) {
  return ref.watch(restockRepositoryProvider).watchRequest(id);
});
