import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFunctions _functions;
  RestockRepository(this._db, this._functions);

  Stream<List<SupplierProfile>> watchActiveSuppliers() {
    return _db
        .collection('suppliers')
        .where('verificationStatus', isEqualTo: 'active')
        .orderBy('companyName')
        .snapshots()
        .map((snap) => snap.docs.map((d) => SupplierProfile.fromMap(d.id, d.data())).toList());
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
      final result = await _functions.httpsCallable('createRestockRequest').call<Map<String, dynamic>>({
        'supplierId': supplierId,
        'items': items
            .map((i) => {
                  'productId': i.productId,
                  'requestedQuantity': i.requestedQuantity,
                  'estimatedUnitCost': i.estimatedUnitCost,
                })
            .toList(),
        'notes': notes,
      });
      return result.data['restockRequestId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw RestockException(e.message ?? 'Could not create restocking request.');
    }
  }

  Future<void> _respond(String requestId, String action, {String? reason, DateTime? estimatedDelivery}) async {
    try {
      await _functions.httpsCallable('respondToRestockRequest').call<Map<String, dynamic>>({
        'restockRequestId': requestId,
        'action': action,
        'reason': reason,
        'estimatedDeliveryIso': estimatedDelivery?.toIso8601String(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw RestockException(e.message ?? 'Could not update this request.');
    }
  }

  Future<void> accept(String requestId, {DateTime? estimatedDelivery}) => _respond(requestId, 'accept', estimatedDelivery: estimatedDelivery);
  Future<void> reject(String requestId, String reason) => _respond(requestId, 'reject', reason: reason);
  Future<void> markProcessing(String requestId) => _respond(requestId, 'processing');
  Future<void> dispatch(String requestId) => _respond(requestId, 'dispatch');
  Future<void> cancel(String requestId) => _respond(requestId, 'cancel');

  Future<void> confirmDelivery(String requestId, List<RestockRequestItem> receivedItems) async {
    try {
      await _functions.httpsCallable('confirmRestockDelivery').call<Map<String, dynamic>>({
        'restockRequestId': requestId,
        'receivedItems': receivedItems
            .map((i) => {'productId': i.productId, 'receivedQuantity': i.receivedQuantity ?? 0})
            .toList(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw RestockException(e.message ?? 'Could not confirm delivery.');
    }
  }

  Stream<List<RestockRequest>> watchMerchantRequests(String merchantId) {
    return _db
        .collection('restock_requests')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => RestockRequest.fromMap(d.id, d.data())).toList());
  }

  Stream<List<RestockRequest>> watchSupplierRequests(String supplierId) {
    return _db
        .collection('restock_requests')
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => RestockRequest.fromMap(d.id, d.data())).toList());
  }

  Stream<RestockRequest?> watchRequest(String id) {
    return _db.collection('restock_requests').doc(id).snapshots().map((d) => d.exists ? RestockRequest.fromMap(d.id, d.data()!) : null);
  }
}

final restockRepositoryProvider = Provider<RestockRepository>((ref) {
  return RestockRepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
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
