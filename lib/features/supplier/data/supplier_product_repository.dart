import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/supplier.dart';

class SupplierProductRepository {
  final FirebaseFirestore _db;
  SupplierProductRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('supplier_products');

  Stream<List<SupplierProduct>> watchMyProducts(String supplierId) {
    return _col
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SupplierProduct.fromMap(d.id, d.data())).toList());
  }

  Stream<List<SupplierProduct>> watchSupplierCatalog(String supplierId) {
    return _col
        .where('supplierId', isEqualTo: supplierId)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SupplierProduct.fromMap(d.id, d.data())).toList());
  }

  Stream<SupplierProduct?> watchProduct(String id) {
    return _col.doc(id).snapshots().map((d) => d.exists ? SupplierProduct.fromMap(d.id, d.data()!) : null);
  }

  Future<void> create({
    required String supplierId,
    required String name,
    required String description,
    required String category,
    required double unitCost,
    required String unit,
    required int minOrderQuantity,
  }) async {
    await _col.add({
      'supplierId': supplierId,
      'name': name,
      'description': description,
      'category': category,
      'unitCost': unitCost,
      'unit': unit,
      'minOrderQuantity': minOrderQuantity,
      'isAvailable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _col.doc(id).update(patch);
  }

  Future<void> setAvailability(String id, bool isAvailable) async {
    await _col.doc(id).update({'isAvailable': isAvailable});
  }
}

final supplierProductRepositoryProvider = Provider<SupplierProductRepository>((ref) {
  return SupplierProductRepository(ref.watch(firestoreProvider));
});

final mySupplierProductsProvider = StreamProvider<List<SupplierProduct>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(supplierProductRepositoryProvider).watchMyProducts(user.id);
});

final supplierCatalogProvider = StreamProvider.family<List<SupplierProduct>, String>((ref, supplierId) {
  return ref.watch(supplierProductRepositoryProvider).watchSupplierCatalog(supplierId);
});
