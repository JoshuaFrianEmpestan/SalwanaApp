import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/providers/firebase_providers.dart';
import '../../../models/store.dart';

/// A merchant's store doc id is the same as their user id (§18 `stores`),
/// so lookups never need a query — just `stores/{merchantId}`.
class StoreRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  StoreRepository(this._db, this._auth);

  DocumentReference<Map<String, dynamic>> _ref(String merchantId) => _db.collection('stores').doc(merchantId);

  Stream<Store?> watchStore(String merchantId) {
    return _ref(merchantId).snapshots().map((doc) => doc.exists ? Store.fromMap(doc.id, doc.data()!) : null);
  }

  Future<void> syncStore() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    try {
      await http.post(
        Uri.parse('https://salwanaapp.onrender.com/syncStore'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
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
  return StoreRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider));
});

/// Live stream of the signed-in merchant's own store.
final myStoreProvider = StreamProvider<Store?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(storeRepositoryProvider).watchStore(user.id);
});
