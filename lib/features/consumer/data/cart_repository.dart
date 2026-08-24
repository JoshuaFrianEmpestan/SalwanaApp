import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/cart_item.dart';
import '../../../models/product.dart';

class CartRepository {
  final FirebaseFirestore _db;
  CartRepository(this._db);

  CollectionReference<Map<String, dynamic>> _items(String userId) =>
      _db.collection('carts').doc(userId).collection('items');

  Stream<List<CartItem>> watchCart(String userId) {
    return _items(userId).snapshots().map((snap) => snap.docs.map((d) => CartItem.fromMap(d.id, d.data())).toList());
  }

  /// Adds [quantity] of [product] to the cart, capped at live available
  /// stock. This is a convenience check for UX only — the checkout Cloud
  /// Function re-validates everything server-side before charging anyone.
  Future<void> addToCart({required String userId, required Product product, required String storeName, required int quantity}) async {
    final ref = _items(userId).doc(product.id);
    final existing = await ref.get();
    final currentQty = existing.exists ? (existing.data()?['quantity'] ?? 0) as int : 0;
    final newQty = (currentQty + quantity).clamp(1, product.availableStock);

    await ref.set(
      CartItem(
        productId: product.id,
        storeId: product.storeId,
        storeName: storeName,
        productName: product.name,
        productImageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : null,
        unitPrice: product.sellingPrice,
        quantity: newQty,
        unit: product.unit,
        addedAt: DateTime.now(),
      ).toMap()
        ..['addedAt'] = existing.exists ? existing.data()!['addedAt'] : FieldValue.serverTimestamp(),
    );
  }

  Future<void> updateQuantity(String userId, String productId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(userId, productId);
      return;
    }
    await _items(userId).doc(productId).update({'quantity': quantity});
  }

  Future<void> removeItem(String userId, String productId) async {
    await _items(userId).doc(productId).delete();
  }

  Future<void> removeItems(String userId, List<String> productIds) async {
    final batch = _db.batch();
    for (final id in productIds) {
      batch.delete(_items(userId).doc(id));
    }
    await batch.commit();
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(firestoreProvider));
});

final cartItemsProvider = StreamProvider<List<CartItem>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(cartRepositoryProvider).watchCart(user.id);
});
