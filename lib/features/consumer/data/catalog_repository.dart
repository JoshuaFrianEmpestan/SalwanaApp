import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/product.dart';
import '../../../models/store.dart';

/// Read-only browsing queries for the consumer catalog (§1, §13 Consumer
/// Dashboard, §17). Merchants own writes to `stores`/`products` (module 3);
/// this repository only ever reads what's already public/active.
class CatalogRepository {
  final FirebaseFirestore _db;
  CatalogRepository(this._db);

  Stream<List<Store>> watchActiveStores() {
    return _db
        .collection('stores')
        .where('verificationStatus', isEqualTo: 'active')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Store.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Product>> watchStoreActiveProducts(String storeId) {
    return _db
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList());
  }

  /// Bounded catalog-wide feed for search/browse — client-side filtered
  /// for search text/category/brand/price since Firestore has no
  /// full-text search. Fine at demo/small-catalog scale.
  Stream<List<Product>> watchCatalog({int limit = 300}) {
    return _db
        .collection('products')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList());
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(firestoreProvider));
});

final activeStoresProvider = StreamProvider<List<Store>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchActiveStores();
});

final storeActiveProductsProvider = StreamProvider.family<List<Product>, String>((ref, storeId) {
  return ref.watch(catalogRepositoryProvider).watchStoreActiveProducts(storeId);
});

final catalogFeedProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchCatalog();
});
