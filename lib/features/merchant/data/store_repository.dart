import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/store.dart';

/// A merchant's store doc id is the same as their user id (§18 `stores`),
/// so lookups never need a query — just `stores/{merchantId}`.
class StoreRepository {
  final FirebaseFirestore _db;
  StoreRepository(this._db);

  DocumentReference<Map<String, dynamic>> _ref(String merchantId) => _db.collection('stores').doc(merchantId);

  Stream<Store?> watchStore(String merchantId) {
    return _ref(merchantId).snapshots().map((doc) => doc.exists ? Store.fromMap(doc.id, doc.data()!) : null);
  }

  Future<Store?> getStore(String merchantId) async {
    final doc = await _ref(merchantId).get();
    return doc.exists ? Store.fromMap(doc.id, doc.data()!) : null;
  }

  Future<void> updateStore(String merchantId, Map<String, dynamic> patch) async {
    await _ref(merchantId).update({...patch, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<Store?> watchStoreById(String storeId) => watchStore(storeId);
}

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(ref.watch(firestoreProvider));
});

/// Live stream of the signed-in merchant's own store.
final myStoreProvider = StreamProvider<Store?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(storeRepositoryProvider).watchStore(user.id);
});
