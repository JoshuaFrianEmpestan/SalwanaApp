import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/firestore_helpers.dart';
import '../../../models/inventory_movement.dart';

class InsufficientStockException implements Exception {
  final String message;
  InsufficientStockException(this.message);
  @override
  String toString() => message;
}

/// Every stock quantity change goes through here, wrapped in a Firestore
/// transaction so a read-then-write race can never push stock negative
/// (§3, §21 "Stock cannot become negative", §20 "database transactions for
/// ... inventory updates"). Each call also appends the matching
/// `inventory_movements` audit record in the same transaction.
class InventoryRepository {
  final FirebaseFirestore _db;
  InventoryRepository(this._db);

  DocumentReference<Map<String, dynamic>> _productRef(String productId) =>
      _db.collection('products').doc(productId);

  static const _manualTypes = {
    MovementType.stockIn,
    MovementType.damage,
    MovementType.expired,
    MovementType.returned,
    MovementType.manualAdjustment,
  };

  /// Adds/removes stock for the merchant-initiated movement types. [quantity]
  /// is always a positive count the user entered — the sign to apply is
  /// derived from [type] (stock in/returns add, damage/expired remove).
  Future<void> recordAdjustment({
    required String productId,
    required String storeId,
    required MovementType type,
    required int quantity,
    required String reason,
    required String performedByUserId,
    required String performedByName,
  }) async {
    assert(_manualTypes.contains(type));
    assert(quantity > 0);

    final signedChange = (type == MovementType.stockIn || type == MovementType.returned) ? quantity : -quantity;

    await _apply(
      productId: productId,
      storeId: storeId,
      type: type,
      signedChange: signedChange,
      reason: reason,
      performedByUserId: performedByUserId,
      performedByName: performedByName,
    );
  }

  /// Manual Adjustment as a physical-count reconciliation: the merchant
  /// enters the *correct* current stock count and the delta is computed
  /// from whatever is live in Firestore at transaction time.
  Future<void> setStockCount({
    required String productId,
    required String storeId,
    required int newCount,
    required String reason,
    required String performedByUserId,
    required String performedByName,
  }) async {
    final productRef = _productRef(productId);
    final movementRef = _db.collection('inventory_movements').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(productRef);
      if (!snap.exists) throw Exception('Product not found.');
      final before = asInt(snap.data()!['currentStock']);
      final delta = newCount - before;
      if (delta == 0) return;

      tx.update(productRef, {'currentStock': newCount, 'updatedAt': FieldValue.serverTimestamp()});
      tx.set(movementRef, InventoryMovement(
        id: movementRef.id,
        productId: productId,
        storeId: storeId,
        type: MovementType.manualAdjustment,
        quantityBefore: before,
        quantityChanged: delta,
        quantityAfter: newCount,
        reason: reason,
        performedByUserId: performedByUserId,
        performedByName: performedByName,
        createdAt: DateTime.now(),
      ).toMap()
        ..['createdAt'] = FieldValue.serverTimestamp());
    });
  }

  Future<void> _apply({
    required String productId,
    required String storeId,
    required MovementType type,
    required int signedChange,
    required String reason,
    required String performedByUserId,
    required String performedByName,
    String? relatedOrderId,
    String? relatedReservationId,
    String? relatedDeliveryId,
  }) async {
    final productRef = _productRef(productId);
    final movementRef = _db.collection('inventory_movements').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(productRef);
      if (!snap.exists) throw Exception('Product not found.');
      final before = asInt(snap.data()!['currentStock']);
      final after = before + signedChange;
      if (after < 0) {
        throw InsufficientStockException(
          'Not enough stock — current stock is $before, this action would reduce it below zero.',
        );
      }

      tx.update(productRef, {'currentStock': after, 'updatedAt': FieldValue.serverTimestamp()});
      tx.set(movementRef, InventoryMovement(
        id: movementRef.id,
        productId: productId,
        storeId: storeId,
        type: type,
        quantityBefore: before,
        quantityChanged: signedChange,
        quantityAfter: after,
        reason: reason,
        relatedOrderId: relatedOrderId,
        relatedReservationId: relatedReservationId,
        relatedDeliveryId: relatedDeliveryId,
        performedByUserId: performedByUserId,
        performedByName: performedByName,
        createdAt: DateTime.now(),
      ).toMap()
        ..['createdAt'] = FieldValue.serverTimestamp());
    });
  }

  Stream<List<InventoryMovement>> watchMovements(String productId) {
    return _db
        .collection('inventory_movements')
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => InventoryMovement.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(firestoreProvider));
});

final productMovementsProvider = StreamProvider.family<List<InventoryMovement>, String>((ref, productId) {
  return ref.watch(inventoryRepositoryProvider).watchMovements(productId).handleError((e, st) {
    // ignore: avoid_print
    print('productMovementsProvider error: $e');
  });
});
