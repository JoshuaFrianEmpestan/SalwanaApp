import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/followed_product.dart';
import '../../../models/product.dart';

/// Consumers follow an out-of-stock product to get a Back-in-Stock alert
/// (§4, §9, §13). Doc id is `{consumerId}_{productId}` so a consumer can
/// never double-follow the same product.
class FollowedProductRepository {
  final FirebaseFirestore _db;
  FollowedProductRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('followed_products');

  String _docId(String consumerId, String productId) => '${consumerId}_$productId';

  Future<void> follow({required String consumerId, required Product product, required String storeName}) async {
    await _col.doc(_docId(consumerId, product.id)).set({
      'consumerId': consumerId,
      'storeId': product.storeId,
      'storeName': storeName,
      'productId': product.id,
      'productName': product.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollow(String consumerId, String productId) async {
    await _col.doc(_docId(consumerId, productId)).delete();
  }

  Stream<bool> isFollowing(String consumerId, String productId) {
    return _col.doc(_docId(consumerId, productId)).snapshots().map((d) => d.exists);
  }

  Stream<List<FollowedProduct>> watchMyFollows(String consumerId) {
    return _col.where('consumerId', isEqualTo: consumerId).snapshots().map(
          (s) => s.docs.map((d) => FollowedProduct.fromMap(d.id, d.data())).toList(),
        );
  }
}

final followedProductRepositoryProvider = Provider<FollowedProductRepository>((ref) {
  return FollowedProductRepository(ref.watch(firestoreProvider));
});

final isFollowingProvider = StreamProvider.family<bool, String>((ref, productId) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(false);
  return ref.watch(followedProductRepositoryProvider).isFollowing(user.id, productId);
});

final myFollowedProductsProvider = StreamProvider<List<FollowedProduct>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(followedProductRepositoryProvider).watchMyFollows(user.id);
});
