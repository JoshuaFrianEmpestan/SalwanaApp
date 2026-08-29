import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/address.dart';

class AddressRepository {
  final FirebaseFirestore _db;
  AddressRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('addresses');

  Stream<List<Address>> watchAddresses(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map(
          (s) => s.docs.map((d) => Address.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.isDefault == a.isDefault ? b.createdAt.compareTo(a.createdAt) : (b.isDefault ? 1 : -1)),
        );
  }

  Future<void> addAddress({
    required String userId,
    required String label,
    required String recipientName,
    required String phone,
    required String line1,
    String? line2,
    required String city,
    required String province,
    required String postalCode,
    bool isDefault = false,
  }) async {
    if (isDefault) await _clearDefault(userId);
    await _col.add({
      'userId': userId,
      'label': label,
      'recipientName': recipientName,
      'phone': phone,
      'line1': line1,
      'line2': line2,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      'isDefault': isDefault,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAddress(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> setDefault(String userId, String id) async {
    await _clearDefault(userId);
    await _col.doc(id).update({'isDefault': true});
  }

  Future<void> _clearDefault(String userId) async {
    final existing = await _col.where('userId', isEqualTo: userId).where('isDefault', isEqualTo: true).get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.update(doc.reference, {'isDefault': false});
    }
    await batch.commit();
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.watch(firestoreProvider));
});

final myAddressesProvider = StreamProvider<List<Address>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(addressRepositoryProvider).watchAddresses(user.id);
});
