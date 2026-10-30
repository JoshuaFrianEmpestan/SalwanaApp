import 'dart:async';
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
    final controller = StreamController<Store?>();
    _ref(merchantId).get().then((doc) async {
      if (doc.exists) {
        final userDoc = await _db.collection('users').doc(merchantId).get();
        final userStatus = userDoc.data()?['status'];
        if (userStatus == 'active' && doc.data()?['verificationStatus'] != 'active') {
          await _ref(merchantId).update({'verificationStatus': 'active', 'updatedAt': FieldValue.serverTimestamp()});
        }
        _ref(merchantId).snapshots().listen(
          (d) => controller.add(d.exists ? Store.fromMap(d.id, d.data()!) : null),
          onError: controller.addError,
        );
      } else {
        final snap = await _db.collection('stores').where('merchantId', isEqualTo: merchantId).limit(1).get();
        if (snap.docs.isNotEmpty) {
          final storeDoc = snap.docs.first;
          final userDoc = await _db.collection('users').doc(merchantId).get();
          final userStatus = userDoc.data()?['status'];
          if (userStatus == 'active' && storeDoc.data()['verificationStatus'] != 'active') {
            await _db.collection('stores').doc(storeDoc.id).update({'verificationStatus': 'active', 'updatedAt': FieldValue.serverTimestamp()});
          }
          _db.collection('stores').doc(storeDoc.id).snapshots().listen(
            (d) => controller.add(d.exists ? Store.fromMap(d.id, d.data()!) : null),
            onError: controller.addError,
          );
        } else {
          final userDoc = await _db.collection('users').doc(merchantId).get();
          final userStatus = userDoc.data()?['status'];
          final storeStatus = userStatus == 'active' ? 'active' : 'pendingVerification';
          await _ref(merchantId).set({
            'merchantId': merchantId,
            'name': 'My Store',
            'description': '',
            'category': 'General',
            'phone': '',
            'email': '',
            'addressLine': '',
            'city': '',
            'verificationStatus': storeStatus,
            'barcodeEnabled': false,
            'reservationExpirationMinutes': 120,
            'averageRating': 0,
            'ratingCount': 0,
            'planTier': 'free',
            'isOpen': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          _ref(merchantId).snapshots().listen(
            (d) => controller.add(d.exists ? Store.fromMap(d.id, d.data()!) : null),
            onError: controller.addError,
          );
        }
      }
    }).catchError(controller.addError);
    return controller.stream;
  }

  Future<Store?> getStore(String merchantId) async {
    final doc = await _ref(merchantId).get();
    if (doc.exists) {
      final userDoc = await _db.collection('users').doc(merchantId).get();
      final userStatus = userDoc.data()?['status'];
      if (userStatus == 'active' && doc.data()?['verificationStatus'] != 'active') {
        await _ref(merchantId).update({'verificationStatus': 'active', 'updatedAt': FieldValue.serverTimestamp()});
        final updated = await _ref(merchantId).get();
        return Store.fromMap(updated.id, updated.data()!);
      }
      return Store.fromMap(doc.id, doc.data()!);
    }
    final snap = await _db.collection('stores').where('merchantId', isEqualTo: merchantId).limit(1).get();
    if (snap.docs.isNotEmpty) {
      final storeDoc = snap.docs.first;
      final userDoc = await _db.collection('users').doc(merchantId).get();
      final userStatus = userDoc.data()?['status'];
      if (userStatus == 'active' && storeDoc.data()['verificationStatus'] != 'active') {
        await _db.collection('stores').doc(storeDoc.id).update({'verificationStatus': 'active', 'updatedAt': FieldValue.serverTimestamp()});
        final updated = await _db.collection('stores').doc(storeDoc.id).get();
        return Store.fromMap(updated.id, updated.data()!);
      }
      return Store.fromMap(storeDoc.id, storeDoc.data());
    }
    final userDoc = await _db.collection('users').doc(merchantId).get();
    final userStatus = userDoc.data()?['status'];
    final storeStatus = userStatus == 'active' ? 'active' : 'pendingVerification';
    await _ref(merchantId).set({
      'merchantId': merchantId,
      'name': 'My Store',
      'description': '',
      'category': 'General',
      'phone': '',
      'email': '',
      'addressLine': '',
      'city': '',
      'verificationStatus': storeStatus,
      'barcodeEnabled': false,
      'reservationExpirationMinutes': 120,
      'averageRating': 0,
      'ratingCount': 0,
      'planTier': 'free',
      'isOpen': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final created = await _ref(merchantId).get();
    return created.exists ? Store.fromMap(created.id, created.data()!) : null;
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
