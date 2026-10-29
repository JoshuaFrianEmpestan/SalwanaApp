import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/inventory_movement.dart';
import '../../../models/product.dart';

class ProductRepository {
  final FirebaseFirestore _db;
  ProductRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _products => _db.collection('products');

  Stream<List<Product>> watchStoreProducts(String storeId) {
    return _products
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<Product?> watchProduct(String productId) {
    return _products.doc(productId).snapshots().map((d) => d.exists ? Product.fromMap(d.id, d.data()!) : null);
  }

  /// Creates a product and, if it starts with stock on hand, writes the
  /// matching `inventory_movements` Stock In entry in the same batch so the
  /// audit trail always accounts for every unit (§3).
  Future<String> createProduct({
    required String storeId,
    required String merchantId,
    required String name,
    required String description,
    required String category,
    required String brand,
    required List<String> imageUrls,
    String? supplierId,
    required double costPrice,
    required double sellingPrice,
    required int initialStock,
    required int minStockLevel,
    required String unit,
    String? batchNumber,
    DateTime? expirationDate,
    String? barcode,
    required String performedByUserId,
    required String performedByName,
  }) async {
    final productRef = _products.doc();
    final batch = _db.batch();

    batch.set(productRef, {
      'storeId': storeId,
      'merchantId': merchantId,
      'name': name,
      'description': description,
      'category': category,
      'brand': brand,
      'imageUrls': imageUrls,
      'supplierId': supplierId,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'currentStock': initialStock,
      'reservedStock': 0,
      'minStockLevel': minStockLevel,
      'unit': unit,
      'batchNumber': batchNumber,
      'expirationDate': expirationDate,
      'barcode': barcode,
      'status': ProductStatus.active.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (initialStock > 0) {
      final movementRef = _db.collection('inventory_movements').doc();
      batch.set(movementRef, InventoryMovement(
        id: movementRef.id,
        productId: productRef.id,
        storeId: storeId,
        type: MovementType.stockIn,
        quantityBefore: 0,
        quantityChanged: initialStock,
        quantityAfter: initialStock,
        reason: 'Initial stock on product creation',
        performedByUserId: performedByUserId,
        performedByName: performedByName,
        createdAt: DateTime.now(),
      ).toMap()
        ..['createdAt'] = FieldValue.serverTimestamp());
    }

    await batch.commit();
    return productRef.id;
  }

  /// Updates non-stock product fields only. Stock quantities must go
  /// through the inventory movement transaction (module 4) so every change
  /// is audited and can never go negative.
  Future<void> updateProductDetails(String productId, Map<String, dynamic> patch) async {
    await _products.doc(productId).update({...patch, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> setStatus(String productId, ProductStatus status) async {
    await _products.doc(productId).update({'status': status.name, 'updatedAt': FieldValue.serverTimestamp()});
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(firestoreProvider));
});

final storeProductsProvider = StreamProvider.family<List<Product>, String>((ref, storeId) {
  return ref.watch(productRepositoryProvider).watchStoreProducts(storeId).handleError((e, st) {
    // ignore: avoid_print
    print('storeProductsProvider error: $e');
  });
});
