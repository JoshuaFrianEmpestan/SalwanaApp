import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/supplier.dart';

class SupplierProfileRepository {
  final FirebaseFirestore _db;
  SupplierProfileRepository(this._db);

  Stream<SupplierProfile?> watchProfile(String supplierId) {
    return _db.collection('suppliers').doc(supplierId).snapshots().map((d) => d.exists ? SupplierProfile.fromMap(d.id, d.data()!) : null);
  }

  Future<void> updateProfile(String supplierId, Map<String, dynamic> patch) async {
    await _db.collection('suppliers').doc(supplierId).update({...patch, 'updatedAt': FieldValue.serverTimestamp()});
  }
}

final supplierProfileRepositoryProvider = Provider<SupplierProfileRepository>((ref) {
  return SupplierProfileRepository(ref.watch(firestoreProvider));
});

final mySupplierProfileProvider = StreamProvider<SupplierProfile?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(supplierProfileRepositoryProvider).watchProfile(user.id);
});
